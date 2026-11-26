import QtQuick
import QtTest
import "calendar.js" as Calendar

// The calendar's decisions, from a fixed now (Wednesday 25 November 2026, 14:00).
TestCase {
  name: "calendar"

  readonly property date now: new Date(2026, 10, 25, 14, 0)
  readonly property string today: "2026-11-25"

  function at(hours, minutes) {
    return new Date(2026, 10, 25, hours, minutes);
  }

  function keys(read, title) {
    return read.rows.filter(row => row.event.title === title).map(row => row.key);
  }

  // Each event under every day it overlaps, all-day ones first, within the days synced, else a year either side of now; one without length under the day it starts.
  function test_timeline() {
    const synced = Calendar.timeline({ synced: { from: "2026-11-01", to: "2026-11-30" }, events: [
      { title: "Night shift", start: "2026-11-12T22:00", end: "2026-11-14T01:00", color: "#4285f4" },
      { title: "Ages", start: "1500-01-01", end: "2500-01-01", allDay: true },
      { title: "Holiday", start: "2026-11-12", end: "2026-11-12", allDay: true, uid: "h", location: " Home\n  Lisbon " },
      { title: "Moment", start: "2026-11-20T10:00", end: "2026-11-20T10:00" }
    ] }, now);
    compare(keys(synced, "Ages").length, 30);
    compare(keys(synced, "Night shift"), ["2026-11-12", "2026-11-13", "2026-11-14"]);
    compare(keys(synced, "Holiday"), ["2026-11-12"]);
    compare(keys(synced, "Moment"), ["2026-11-20"]);
    compare(synced.days["2026-11-12"].map(event => event.title), ["Ages", "Holiday", "Night shift"]);
    compare(synced.events.map(event => event.title), ["Ages", "Holiday", "Night shift", "Moment"]);
    compare(synced.events[1].location, "Home, Lisbon");
    compare(synced.events[1].id, "2026-11-12 h");
    compare(synced.events[2].id, "2026-11-12T22:00 #4285f4 Night shift");
    compare(synced.synced, { from: "2026-11-01", to: "2026-11-30" });
    const unsynced = Calendar.timeline({ events: [{ title: "Ages", start: "1500-01-01", end: "2500-01-01", allDay: true }] }, now);
    compare(keys(unsynced, "Ages").length, 731);
    compare(unsynced.rows[0].key, "2025-11-25");
    compare(unsynced.synced, null);
  }

  // Today's timed events that are over fold into one line where the first was, so its heading and what is next stay in view; a day without events shows still.
  function test_rows() {
    const rows = [
      { id: "a", key: today, event: { title: "Holiday", allDay: true, end: at(24, 0) } },
      { id: "b", key: today, event: { title: "Standup", allDay: false, end: at(13, 59) } },
      { id: "c", key: today, event: { title: "Review", allDay: false, end: at(15, 0) } },
      { id: "d", key: today, event: { title: "Coffee", allDay: false, end: at(14, 0) } },
      { id: "e", key: "2026-11-27", event: { title: "Gym", allDay: false, end: new Date(2026, 10, 27, 10) } }
    ];
    const ids = rows.filter(row => Calendar.earlier(row, now)).map(row => row.id);
    compare(ids, ["b", "d"]);
    const titles = list => list.map(row => row.earlier ? row.earlier.map(event => event.title).join("+") : row.event ? row.event.title : row.key);
    compare(titles(Calendar.rows(rows, today, ids)), ["Holiday", "Standup+Coffee", "Review", "Gym"]);
    verify(Calendar.rows(rows, today, []) === rows);
    compare(titles(Calendar.rows(rows, "2026-11-26", [])), ["Holiday", "Standup", "Review", "Coffee", "2026-11-26", "Gym"]);
    compare(titles(Calendar.rows(rows, "2026-12-01", [])).slice(-1), ["2026-12-01"]);
  }

  // Today starts at its first timed event not over yet, another day at its first.
  function test_firstOn() {
    const rows = [
      { key: "2000-01-01", event: { allDay: false, end: new Date(2000, 0, 1, 10) } },
      { key: today, event: { allDay: true, end: at(24, 0) } },
      { key: today, event: { allDay: false, end: at(13, 59) } },
      { key: today, event: { allDay: false, end: at(15, 0) } }
    ];
    compare(Calendar.firstOn(rows, today, now), 3);
    compare(Calendar.firstOn(rows, "2000-01-01", now), 0);
    compare(Calendar.firstOn(rows, "1999-01-01", now), 0);
    compare(Calendar.firstOn(rows, today, new Date(2026, 10, 26, 9, 0)), 1);
  }

  // Timed events first, so a daily all-day one does not hold `next`; `more` counts the timed events starting later today besides it.
  function test_next() {
    const day = { title: "Habit", start: new Date(2026, 10, 25), end: new Date(2026, 10, 26), allDay: true };
    const event = (title, start, end) => ({ title, start, end, allDay: false });
    const standup = event("Standup", at(13, 0), at(14, 30));
    const review = event("Review", at(15, 0), at(16, 0));
    const coffee = event("Coffee", at(17, 0), at(17, 15));
    const gym = event("Gym", new Date(2026, 10, 26, 9, 0), new Date(2026, 10, 26, 10, 0));
    const swim = event("Swim", new Date(2026, 10, 26, 11, 0), new Date(2026, 10, 26, 12, 0));
    // None after.
    compare(Calendar.next([day, coffee], now).title, "Coffee");
    compare(Calendar.more([day, coffee], coffee, now), 0);
    // Two after, tomorrow's not counted.
    const events = [day, review, coffee, event("Dinner", at(20, 0), at(21, 0)), gym];
    compare(Calendar.next(events, now).title, "Review");
    compare(Calendar.more(events, review, now), 2);
    // One under way is next, those starting later today after it.
    const busy = [day, standup, review, coffee, gym, swim];
    compare(Calendar.next(busy, now).title, "Standup");
    compare(Calendar.more(busy, standup, now), 2);
    // Late in the day, tomorrow's events are not today's to count.
    const late = new Date(2026, 10, 25, 23, 0);
    compare(Calendar.next(busy, late).title, "Gym");
    compare(Calendar.more(busy, gym, late), 0);
    compare(Calendar.more(busy, gym, new Date(2026, 10, 26, 0, 0)), 1);
    // With no timed event left, the all-day one is next, and none follow.
    compare(Calendar.next([day, standup], at(15, 0)).title, "Habit");
    compare(Calendar.more([day, standup], day, at(15, 0)), 0);
    compare(Calendar.next([], now), null);
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
    // Before 0 reminds at the start, and once: a restart then keeps the id.
    const start = Calendar.due(events, [], at(14, 5), 0);
    compare(start.remind.map(event => event.id), ["soon"]);
    compare(Calendar.due(events, start.fired, at(14, 5), 0).remind, []);
  }
}
