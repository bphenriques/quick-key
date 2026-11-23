import QtQuick
import QtTest
import "clock.js" as Clock

// How a moment is said, from a fixed now (Wednesday 25 November 2026, 14:00) and en_GB's words.
TestCase {
  name: "clock"

  readonly property var names: Clock.names(Qt.locale("en_GB"), Locale.ShortFormat)
  readonly property date now: new Date(2026, 10, 25, 14, 0)

  function at(days, hours = 9, minutes = 30) {
    return new Date(2026, 10, 25 + days, hours, minutes);
  }

  // Near days by name, the coming week by weekday, else the date (the past too), with its year when not this one.
  function test_day() {
    compare(Clock.recent(at(0, 9, 5), now, names), "09:05");
    compare(Clock.recent(at(-1), now, names), "yesterday");
    compare(Clock.day(at(1), now, names), "tomorrow");
    compare(Clock.day(at(3), now, names), "Sat");
    compare(Clock.recent(at(-3), now, names), "22 Nov");
    compare(Clock.day(at(-10), now, names), "15 Nov");
    compare(Clock.day(new Date(2025, 5, 3, 9, 30), now, names), "3 Jun 2025");
    compare(Clock.when(at(1), true, now, names), "tomorrow 09:30");
    compare(Clock.when(at(1), false, now, names), "tomorrow");
    compare(Clock.when(at(0), true, now, names), "09:30");
  }

  // Across a new year, by the day, not the date's numbers.
  function test_newYear() {
    const eve = new Date(2026, 11, 31, 23, 59);
    compare(Clock.daysFrom(new Date(2027, 0, 1, 0, 1), eve), 1);
    compare(Clock.day(new Date(2027, 0, 1), eve, names), "tomorrow");
    compare(Clock.day(new Date(2027, 0, 4), eve, names), "Mon");
    compare(Clock.heading(new Date(2027, 0, 2), eve, names), "Saturday 2 January 2027");
    compare(Clock.recent(new Date(2026, 11, 30, 8, 0), new Date(2027, 0, 1, 0, 0), names), "30 Dec 2026");
  }

  // A day's heading says its year only when it is not this one.
  function test_heading() {
    compare(Clock.heading(now, now, names), "Today");
    compare(Clock.heading(at(-1), now, names), "Yesterday");
    compare(Clock.heading(new Date(2027, 5, 15), now, names), "Tuesday 15 June 2027");
    compare(Clock.heading(new Date(2026, 0, 15), now, names), "Thursday 15 January");
  }

  function test_dayAfter() {
    compare(Clock.dayAfter(new Date(2026, 10, 28, 18, 0), at(0, 0, 0), true, names), "Sat 18:00");
    compare(Clock.dayAfter(new Date(2026, 10, 28, 18, 0), at(0, 0, 0), false, names), "Sat");
    compare(Clock.dayAfter(new Date(2026, 11, 3, 18, 0), at(0, 0, 0), true, names), "3 Dec");
  }

  function test_format() {
    compare(Clock.format(new Date(2026, 10, 1, 9, 5), "%a %A %-d%o %b %B %d/%m/%y %Y %H:%M %I %p %% %q", names), "Sun Sunday 1st Nov November 01/11/26 2026 09:05 09 am % %q");
    compare(Clock.format(new Date(2026, 10, 12, 0, 0), "%-d%o %I", names), "12th 12");
    compare(Clock.ordinal(22) + Clock.ordinal(23) + Clock.ordinal(13), "ndrdth");
  }

  // Short names cut to three letters only where that still tells them apart, without a closing dot.
  function test_abbreviated() {
    compare(names.months[8], "Sep");
    compare(Clock.abbreviated(["Sept", "Oct"]), ["Sep", "Oct"]);
    compare(Clock.abbreviated(["janv.", "juin", "juil."]), ["janv", "juin", "juil"]);
  }

  // As local time, both ways: Date would read a bare date as UTC.
  function test_keys() {
    compare(Clock.parse("2026-11-12").getTime(), new Date(2026, 10, 12).getTime());
    compare(Clock.parse("2026-11-12T14:05").getTime(), new Date(2026, 10, 12, 14, 5).getTime());
    compare(Clock.dayKey(new Date(2026, 0, 2, 23, 59)), "2026-01-02");
    compare(Clock.minuteKey(new Date(2026, 0, 2, 3, 4)), "2026-01-02T03:04");
  }
}
