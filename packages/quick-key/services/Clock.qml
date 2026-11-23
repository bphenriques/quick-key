pragma Singleton

import QtQuick
import Quickshell
import qs
import "clock.js" as Lib

// The time to the minute, its locale (Config.clock, else the machine's), and the one place a moment is said, so every surface says it alike: clock.js, from now.
Singleton {
  id: root

  readonly property date date: clock.date
  readonly property var locale: Config.clock.locale ? Qt.locale(Config.clock.locale) : Qt.locale()
  readonly property int firstDayOfWeek: Config.clock.firstDayOfWeek >= 0 ? Config.clock.firstDayOfWeek : locale.firstDayOfWeek
  readonly property var names: Lib.names(locale, Locale.ShortFormat)
  readonly property var weekdays: names.weekdays
  readonly property string text: Config.clock.format ? Lib.format(date, Config.clock.format, names)
    : date.toLocaleDateString(locale, Locale.LongFormat) + " " + date.toLocaleTimeString(locale, Locale.ShortFormat)
  // As clock.js has them, needing no now.
  readonly property var dayKey: Lib.dayKey
  readonly property var minuteKey: Lib.minuteKey
  readonly property var parse: Lib.parse
  readonly property var moved: Lib.moved

  function time(moment) {
    return Lib.time(moment, names);
  }

  function day(moment) {
    return Lib.day(moment, date, names);
  }

  function when(moment, timed) {
    return Lib.when(moment, timed, date, names);
  }

  function recent(moment) {
    return Lib.recent(moment, date, names);
  }

  function heading(moment) {
    return Lib.heading(moment, date, names);
  }

  function dayAfter(moment, from, timed) {
    return Lib.dayAfter(moment, from, timed, names);
  }

  // Whether a moment is `minutes` or more ago; never for none.
  function stale(moment, minutes) {
    return !!moment && date - moment >= minutes * 60000;
  }

  // A month as a heading (November 2026), in sentence case as `heading` is.
  function monthHeading(moment) {
    const text = locale.standaloneMonthName(moment.getMonth()) + " " + moment.getFullYear();
    return text[0].toUpperCase() + text.slice(1);
  }

  SystemClock {
    id: clock
    precision: SystemClock.Minutes
  }
}
