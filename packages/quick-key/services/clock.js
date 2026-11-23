.pragma library

// How Clock says a moment, pure: each takes `now`, and a locale's `names` (below), so a unit test reads them without a shell (tests/unit).

// A locale's words: its short day and month names, cut to three letters where that still tells them apart (en_GB's Sept), and its time's format; `short` is Locale.ShortFormat, which a library cannot name.
function names(locale, short) {
  return {
    locale,
    weekdays: abbreviated(Array.from({ length: 7 }, (_, day) => locale.dayName(day, short))),
    months: abbreviated(Array.from({ length: 12 }, (_, month) => locale.monthName(month, short))),
    time: locale.timeFormat(short)
  };
}

// Without a closing dot (fr's janv.).
function abbreviated(names) {
  const plain = names.map(name => name.replace(/\.$/, ""));
  const cut = plain.map(name => name.slice(0, 3));
  return new Set(cut).size === cut.length ? cut : plain;
}

// strftime as waybar takes it (%a %A %b %B, the short names as `names` says them, %d %m %y %Y %H %I %M %p %%, %-d unpadded), plus %o, the English ordinal.
function format(date, pattern, names) {
  const pad = (value, flag) => flag === "-" ? String(value) : String(value).padStart(2, "0");
  return pattern.replace(/%(-?)([a-zA-Z%])/g, (all, flag, code) => {
    switch (code) {
    case "a": return names.weekdays[date.getDay()];
    case "A": return names.locale.dayName(date.getDay());
    case "b": return names.months[date.getMonth()];
    case "B": return names.locale.monthName(date.getMonth());
    case "d": return pad(date.getDate(), flag);
    case "m": return pad(date.getMonth() + 1, flag);
    case "y": return pad(date.getFullYear() % 100, flag);
    case "Y": return String(date.getFullYear());
    case "H": return pad(date.getHours(), flag);
    case "I": return pad(date.getHours() % 12 || 12, flag);
    case "M": return pad(date.getMinutes(), flag);
    case "p": return date.getHours() < 12 ? names.locale.amText : names.locale.pmText;
    case "o": return ordinal(date.getDate());
    case "%": return "%";
    default: return all;
    }
  });
}

const nearDays = { "-1": "yesterday", "0": "today", "1": "tomorrow" };

// A time as the locale writes it (14:30, 2:30 PM).
function time(moment, names) {
  return moment.toLocaleTimeString(names.locale, names.time);
}

// Whole days from now to a moment's day: 0 today, 1 tomorrow, -1 yesterday.
function daysFrom(moment, now) {
  const midnight = day => new Date(day.getFullYear(), day.getMonth(), day.getDate());
  return Math.round((midnight(moment) - midnight(now)) / 86400000);
}

// A day as you would say it: yesterday, today or tomorrow, its weekday within the coming week, else its date (3 Nov), with its year when not this one; a past weekday would read as the next one.
function day(moment, now, names) {
  const days = daysFrom(moment, now);
  return nearDays[days] ?? (days > 0 && days < 7 ? names.weekdays[moment.getDay()] : format(moment, moment.getFullYear() === now.getFullYear() ? "%-d %b" : "%-d %b %Y", names));
}

// A moment as you would say it: today its time, else its day, with its time when `timed` (tomorrow 09:30).
function when(moment, timed, now, names) {
  if (!timed) return day(moment, now, names);
  return daysFrom(moment, now) === 0 ? time(moment, names) : day(moment, now, names) + " " + time(moment, names);
}

// When something last happened, in a list of recent things: its time today, else its day.
function recent(moment, now, names) {
  return when(moment, daysFrom(moment, now) === 0, now, names);
}

// A day as a heading: Yesterday, Today or Tomorrow, else in full (Wednesday 26 November), with its year when not this one, in sentence case where the locale writes names lowercase (pt's terça-feira).
function heading(moment, now, names) {
  const text = nearDays[daysFrom(moment, now)] ?? format(moment, moment.getFullYear() === now.getFullYear() ? "%A %-d %B" : "%A %-d %B %Y", names);
  return text[0].toUpperCase() + text.slice(1);
}

// A later day under the heading of `from`: its weekday within a week, with its time when `timed` (Sat 18:00); beyond, its date alone (3 Dec), as narrow as those.
function dayAfter(moment, from, timed, names) {
  if (moment - from >= 7 * 86400000) return format(moment, "%-d %b", names);
  return timed ? names.weekdays[moment.getDay()] + " " + time(moment, names) : names.weekdays[moment.getDay()];
}

// A day as the files key it: 2026-11-12.
function dayKey(day) {
  return Qt.formatDate(day, "yyyy-MM-dd");
}

// A moment as the files key it, to the minute: 2026-11-12T14:00.
function minuteKey(moment) {
  return Qt.formatDateTime(moment, "yyyy-MM-ddTHH:mm");
}

// "2026-11-12" or "2026-11-12T14:00" as local time: Date would read a bare date as UTC.
function parse(text) {
  const [date, time] = text.split("T");
  const [year, month, day] = date.split("-").map(Number);
  const [hours, minutes] = (time ?? "0:0").split(":").map(Number);
  return new Date(year, month - 1, day, hours, minutes);
}

function ordinal(day) {
  if (day >= 11 && day <= 13) return "th";
  return ["th", "st", "nd", "rd"][day % 10] ?? "th";
}
