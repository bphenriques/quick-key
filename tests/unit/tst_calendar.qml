import QtQuick
import QtTest
import "calendar.js" as Calendar

// The calendar's decisions, from a fixed now (Wednesday 25 November 2026, 14:00).
TestCase {
  name: "calendar"

  readonly property date now: new Date(2026, 10, 25, 14, 0)

  function at(hours, minutes) {
    return new Date(2026, 10, 25, hours, minutes);
  }

  // Each timed event once, ahead by `before` minutes; one reminded before a restart is not again, and one past is forgotten.
  function test_due() {
    const events = [
      { id: "soon", start: at(14, 5), allDay: false },
      { id: "later", start: at(14, 30), allDay: false },
      { id: "day", start: at(14, 5), allDay: true },
      { id: "past", start: at(13, 0), allDay: false },
      { id: "kept", start: at(14, 8), allDay: false }
    ];
    const due = Calendar.due(events, ["kept", "past"], now, 10);
    compare(due.remind.map(event => event.id), ["soon"]);
    compare(due.fired, ["kept", "soon"]);
    compare(Calendar.due(events, due.fired, now, 10).remind, []);
    compare(Calendar.due(events, [], now, 30).remind.map(event => event.id), ["soon", "later", "kept"]);
  }
}
