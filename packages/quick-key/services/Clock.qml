pragma Singleton

import QtQuick
import Quickshell
import qs

// The time to the minute, its locale (Config.clock, else the machine's), and the one place a moment is said, so every surface says it alike.
Singleton {
  id: root

  readonly property date date: clock.date
  readonly property var locale: Config.clock.locale ? Qt.locale(Config.clock.locale) : Qt.locale()
  readonly property int firstDayOfWeek: Config.clock.firstDayOfWeek >= 0 ? Config.clock.firstDayOfWeek : locale.firstDayOfWeek
  readonly property string text: Config.clock.format ? format(date, Config.clock.format)
    : date.toLocaleDateString(locale, Locale.LongFormat) + " " + date.toLocaleTimeString(locale, Locale.ShortFormat)

  // strftime as waybar takes it (%a %A %b %B, the short names as `weekdays` and `months` say them, %d %m %y %Y %H %I %M %p %%, %-d unpadded), plus %o, the English ordinal.
  function format(date, pattern) {
    const pad = (value, flag) => flag === "-" ? String(value) : String(value).padStart(2, "0");
    return pattern.replace(/%(-?)([a-zA-Z%])/g, (all, flag, code) => {
      switch (code) {
      case "a": return weekdays[date.getDay()];
      case "A": return locale.dayName(date.getDay(), Locale.LongFormat);
      case "b": return months[date.getMonth()];
      case "B": return locale.monthName(date.getMonth(), Locale.LongFormat);
      case "d": return pad(date.getDate(), flag);
      case "m": return pad(date.getMonth() + 1, flag);
      case "y": return pad(date.getFullYear() % 100, flag);
      case "Y": return String(date.getFullYear());
      case "H": return pad(date.getHours(), flag);
      case "I": return pad(date.getHours() % 12 || 12, flag);
      case "M": return pad(date.getMinutes(), flag);
      case "p": return date.getHours() < 12 ? locale.amText : locale.pmText;
      case "o": return ordinal(date.getDate());
      case "%": return "%";
      default: return all;
      }
    });
  }

  // Short day and month names, cut to three letters where that still tells them apart (en_GB's Sept), without a closing dot (fr's janv.).
  readonly property var weekdays: abbreviated(Array.from({ length: 7 }, (_, day) => locale.dayName(day, Locale.ShortFormat)))
  readonly property var months: abbreviated(Array.from({ length: 12 }, (_, month) => locale.monthName(month, Locale.ShortFormat)))
  readonly property var nearDays: ({ "-1": "yesterday", "0": "today", "1": "tomorrow" })

  function abbreviated(names) {
    const plain = names.map(name => name.replace(/\.$/, ""));
    const cut = plain.map(name => name.slice(0, 3));
    return new Set(cut).size === cut.length ? cut : plain;
  }

  // A time as the locale writes it (14:30, 2:30 PM).
  function time(moment) {
    return moment.toLocaleTimeString(locale, Locale.ShortFormat);
  }

  // Whole days from today to a moment's day: 0 today, 1 tomorrow, -1 yesterday.
  function daysFrom(moment) {
    const midnight = day => new Date(day.getFullYear(), day.getMonth(), day.getDate());
    return Math.round((midnight(moment) - midnight(date)) / 86400000);
  }

  // A day as you would say it: yesterday, today or tomorrow, its weekday within the coming week, else its date (3 Nov), with its year when not this one; a past weekday would read as the next one.
  function day(moment) {
    const days = daysFrom(moment);
    return nearDays[days] ?? (days > 0 && days < 7 ? weekdays[moment.getDay()] : format(moment, moment.getFullYear() === date.getFullYear() ? "%-d %b" : "%-d %b %Y"));
  }

  // A moment as you would say it: today its time, else its day, with its time when `timed` (tomorrow 09:30).
  function when(moment, timed) {
    if (!timed) return day(moment);
    return daysFrom(moment) === 0 ? time(moment) : day(moment) + " " + time(moment);
  }

  // When something last happened, in a list of recent things: its time today, else its day.
  function recent(moment) {
    return when(moment, daysFrom(moment) === 0);
  }

  // Whether a moment is `minutes` or more ago; never for none.
  function stale(moment, minutes) {
    return !!moment && date - moment >= minutes * 60000;
  }

  // A day as a heading: Yesterday, Today or Tomorrow, else in full (Wednesday 26 November), with its year when not this one, in sentence case where the locale writes names lowercase (pt's terça-feira).
  function heading(moment) {
    const text = nearDays[daysFrom(moment)] ?? format(moment, moment.getFullYear() === date.getFullYear() ? "%A %-d %B" : "%A %-d %B %Y");
    return text[0].toUpperCase() + text.slice(1);
  }

  // A month as a heading (November 2026), in sentence case as `heading` is.
  function monthHeading(moment) {
    const text = locale.standaloneMonthName(moment.getMonth()) + " " + moment.getFullYear();
    return text[0].toUpperCase() + text.slice(1);
  }

  // A later day under the heading of `from`: its weekday within a week, with its time when `timed` (Sat 18:00); beyond, its date alone (3 Dec), as narrow as those.
  function dayAfter(moment, from, timed) {
    if (moment - from >= 7 * 86400000) return format(moment, "%-d %b");
    return timed ? weekdays[moment.getDay()] + " " + time(moment) : weekdays[moment.getDay()];
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

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
