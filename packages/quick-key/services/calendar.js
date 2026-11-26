.pragma library

.import "clock.js" as Dates

// The calendar's decisions, pure: each takes `now`, so a unit test fixes it (tests/unit).

// Text on one line, as a row shows it: an address often comes as several.
function line(text) {
  return (text ?? "").trim().replace(/\s*\n\s*/g, ", ");
}

// The file's events in order, and each once per day it falls on: `days` by key, all-day first, then by start, and `rows` in order, { id, key, day, event }, `id` the same across reads of the file.
function timeline(json, now) {
  const events = Array.from(json.events ?? []).map(event => {
    const start = Dates.parse(event.start);
    const end = Dates.parse(event.end);
    // An all-day event's end is its last day; it runs to the start of the next.
    if (event.allDay) end.setDate(end.getDate() + 1);
    const title = line(event.title);
    // Two alike in title, time and colour differ by uid, which the file may leave out.
    return { id: event.uid ? event.start + " " + event.uid : [event.start, event.color, title].join(" "), title, start, end, allDay: !!event.allDay, color: event.color ?? "", location: line(event.location) };
  }).sort((a, b) => a.start - b.start);
  const synced = json.synced?.from && json.synced?.to ? { from: json.synced.from, to: json.synced.to } : null;
  // Each event under every day it overlaps within the synced days, else a year either side of now, so one spanning centuries is no row a day; one without length (start equals end) under the day it starts on.
  const from = synced ? Dates.parse(synced.from) : new Date(now.getFullYear() - 1, now.getMonth(), now.getDate());
  const to = synced ? Dates.parse(synced.to) : new Date(now.getFullYear() + 1, now.getMonth(), now.getDate());
  const days = {};
  for (const event of events) {
    const last = new Date(Math.min(event.end > event.start ? event.end - 1 : event.start, to));
    const first = event.start > from ? event.start : from;
    for (let day = new Date(first.getFullYear(), first.getMonth(), first.getDate()); day <= last;
         day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)) {
      const key = Dates.dayKey(day);
      if (!days[key]) days[key] = [];
      days[key].push(event);
    }
  }
  const rows = [];
  for (const key of Object.keys(days).sort()) {
    days[key].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
    const day = Dates.parse(key);
    for (const event of days[key]) rows.push({ id: key + " " + event.id, key, day, event });
  }
  return { events, synced, days, rows };
}

// Whether a row is a timed event of today that is over, which the list folds into one line.
function earlier(row, now) {
  return row.key === Dates.dayKey(now) && !!row.event && !row.event.allDay && row.event.end <= now;
}

// Where a day starts in `rows`, for the list to rest on and Return to focus: today, its first timed event not over yet; else the day's first row.
function firstOn(rows, key, now) {
  const next = key === Dates.dayKey(now) ? rows.findIndex(row => row.key === key && row.event && !row.event.allDay && row.event.end > now) : -1;
  return next >= 0 ? next : rows.findIndex(row => row.key >= key);
}

// The list's rows: the timeline's, with the day of `key` in it even when it has no events, and those of `ids` folded into one line where the first was, so what is over leaves today's heading and what is next in view.
function rows(timeline, key, ids) {
  const at = timeline.findIndex(row => row.key >= key);
  const before = at < 0 ? timeline.length : at;
  const all = at >= 0 && timeline[at].key === key ? timeline : timeline.slice(0, before).concat([{ id: "", key, day: Dates.parse(key), event: null }], timeline.slice(before));
  const first = all.find(row => ids.includes(row.id));
  if (!first) return all;
  const folded = { id: first.key + " earlier", key: first.key, day: first.day, event: null, earlier: all.filter(row => ids.includes(row.id)).map(row => row.event) };
  return all.filter(row => row === first || !ids.includes(row.id)).map(row => row === first ? folded : row);
}

// The next event not over yet, timed ones first: an all-day one (a daily habit) would otherwise hold it every day.
function next(events, now) {
  return events.find(event => !event.allDay && event.end > now) ?? events.find(event => event.end > now) ?? null;
}

// How many timed events start later today besides `next`; today's all-day ones have started by then.
function more(events, next, now) {
  const today = Dates.dayKey(now);
  return events.filter(event => event !== next && !event.allDay && event.start > now && Dates.dayKey(event.start) === today).length;
}

// Each timed event once, `before` minutes ahead: those to remind at `now`, and every one fired by id (`reminded`) still to come.
function due(events, reminded, now, before) {
  const until = new Date(now.getTime() + before * 60000);
  const fired = reminded.filter(id => events.some(event => event.id === id && event.start >= now));
  const remind = [];
  for (const event of events) {
    if (event.allDay || event.start < now || event.start > until || fired.includes(event.id)) continue;
    fired.push(event.id);
    remind.push(event);
  }
  return { remind, fired };
}
