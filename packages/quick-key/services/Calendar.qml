pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// Events from Config.calendar.file (docs/src/calendar.md), read again whenever the file is replaced.
Singleton {
  id: root

  // Whether the file has been read; until then the month shows alone.
  readonly property bool enabled: store.loaded
  readonly property var updated: store.updated
  // Whether a sync is running, and why the last one failed ("" when it did not): the file's own word.
  readonly property bool syncing: store.syncing
  readonly property string error: store.error
  // Each event once per day it falls on, in order: { id, key, day, event }, `id` the same across reads of the file.
  readonly property var timeline: store.timeline
  // The next event not over yet, timed ones first: an all-day one (a daily habit) would otherwise hold it every day.
  readonly property var next: store.events.find(event => !event.allDay && event.end > Clock.date)
    ?? store.events.find(event => event.end > Clock.date) ?? null

  // The events on a day, all-day first, then by start.
  function eventsOn(day) {
    return store.days[Clock.dayKey(day)] ?? [];
  }

  function colorsOn(day) {
    return [...new Set(eventsOn(day).map(event => event.color))];
  }

  // Whether the file covers a day, by the range it was synced over; a file that names none covers every day.
  function synced(day) {
    const key = Clock.dayKey(day);
    return !store.synced || key >= store.synced.from && key <= store.synced.to;
  }

  // Where a day starts in `rows` (the timeline's), for the list to rest on and Return to focus: today, its first timed event not over yet; else the day's first row.
  function firstOn(rows, key) {
    const now = key === Clock.dayKey(Clock.date) ? rows.findIndex(row => row.key === key && row.event && !row.event.allDay && row.event.end > Clock.date) : -1;
    return now >= 0 ? now : rows.findIndex(row => row.key >= key);
  }

  // Whether a row is a timed event of today that is over, which the list folds into one line.
  function earlier(row) {
    return row.key === Clock.dayKey(Clock.date) && !!row.event && !row.event.allDay && row.event.end <= Clock.date;
  }

  // Text on one line, as a row shows it: an address often comes as several.
  function line(text) {
    return (text ?? "").trim().replace(/\s*\n\s*/g, ", ");
  }

  QtObject {
    id: store

    property bool loaded: false
    property var updated: null
    property bool syncing: false
    property string error: ""
    // { from, to }, the first and last day synced, as the file keys them; null when it says none.
    property var synced: null
    property var events: []
    property var days: ({})
    property var timeline: []

    function read(json) {
      events = Array.from(json.events ?? []).map(event => {
        const start = Clock.parse(event.start);
        const end = Clock.parse(event.end);
        // An all-day event's end is its last day; it runs to the start of the next.
        if (event.allDay) end.setDate(end.getDate() + 1);
        const title = root.line(event.title);
        // Two alike in title, time and colour differ by uid, which the file may leave out.
        return { id: event.uid ? event.start + " " + event.uid : [event.start, event.color, title].join(" "), title, start, end, allDay: !!event.allDay, color: event.color ?? "", location: root.line(event.location) };
      }).sort((a, b) => a.start - b.start);
      synced = json.synced?.from && json.synced?.to ? { from: json.synced.from, to: json.synced.to } : null;
      // Each event under every day it overlaps within the synced days, else a year either side of today, so one spanning centuries is no row a day; one without length (start equals end) under the day it starts on.
      const today = Clock.date;
      const from = synced ? Clock.parse(synced.from) : new Date(today.getFullYear() - 1, today.getMonth(), today.getDate());
      const to = synced ? Clock.parse(synced.to) : new Date(today.getFullYear() + 1, today.getMonth(), today.getDate());
      const byDay = {};
      for (const event of events) {
        const last = new Date(Math.min(event.end > event.start ? event.end - 1 : event.start, to));
        const first = event.start > from ? event.start : from;
        for (let day = new Date(first.getFullYear(), first.getMonth(), first.getDate()); day <= last;
             day = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1)) {
          const key = Clock.dayKey(day);
          if (!byDay[key]) byDay[key] = [];
          byDay[key].push(event);
        }
      }
      const rows = [];
      for (const key of Object.keys(byDay).sort()) {
        byDay[key].sort((a, b) => (b.allDay - a.allDay) || (a.start - b.start));
        const day = Clock.parse(key);
        for (const event of byDay[key]) rows.push({ id: key + " " + event.id, key, day, event });
      }
      days = byDay;
      timeline = rows;
      updated = json.updated ? Clock.parse(json.updated) : null;
      syncing = !!json.syncing;
      error = json.error ?? "";
      loaded = true;
    }

    function clear() {
      events = [];
      days = {};
      timeline = [];
      updated = null;
      syncing = false;
      error = "";
      synced = null;
      loaded = false;
    }
  }

  // Each timed event once, Config.calendar.remindBefore minutes ahead, on the clock's own minute; kept by id, so a restart repeats none.
  function remind() {
    if (!Config.calendar.remind || !store.loaded) return;
    const now = Clock.date;
    const until = new Date(now.getTime() + Config.calendar.remindBefore * 60000);
    const kept = Array.from(Kept.value("calendar.reminded") ?? []);
    const reminded = kept.filter(id => store.events.some(event => event.id === id && event.start > now));
    for (const event of store.events) {
      if (event.allDay || event.start <= now || event.start > until || reminded.includes(event.id)) continue;
      reminded.push(event.id);
      const when = Clock.time(event.start) + (event.location ? " · " + event.location : "");
      Commands.run(Config.calendar.remind, event.title, when);
    }
    if (reminded.join("\n") !== kept.join("\n")) Kept.set("calendar.reminded", reminded);
  }

  Connections {
    target: Clock

    function onDateChanged() {
      root.remind();
    }
  }

  FileView {
    path: Config.calendar.file
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        store.read(JSON.parse(text()));
      } catch (error) {
        // A file that cannot be read keeps what was shown.
        console.warn("calendar:", Config.calendar.file + ":", error);
      }
    }
    onLoadFailed: store.clear()
  }
}
