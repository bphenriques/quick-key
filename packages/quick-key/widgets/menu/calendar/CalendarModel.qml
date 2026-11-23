import QtQuick
import qs.services
import qs.ui

// A calendar level's state: the selected day, the event in focus, and the keys that move them (docs/src/calendar.md).
QtObject {
  id: root

  readonly property var selected: internal.selected
  // The event in focus, by its row id in Calendar.timeline, so a new read of the file keeps it; "" while the keys move the day.
  readonly property string focused: internal.focused
  // Whether the focused event shows whole, its title and place unshortened.
  readonly property bool details: internal.details
  // Whether today's events that are over show a row each, as the keys have reached one; else they fold into one line.
  readonly property bool unfolded: internal.unfolded

  readonly property string title: Clock.monthHeading(selected)
  // Each moves the selected day by [years, months, days], or back to today (null); the arrows, which the grid shows, are listed on `?` (desc), the rest in the legend (what).
  readonly property var keys: [
    { key: ["Left", "Right"], paired: true, desc: Words.helpDay, moves: { Left: [0, 0, -1], Right: [0, 0, 1] } },
    { key: ["Up", "Down"], paired: true, desc: Words.helpWeek, moves: { Up: [0, 0, -7], Down: [0, 0, 7] } },
    { key: ["Ctrl+Left", "Ctrl+Right"], what: Words.month, moves: { "Ctrl+Left": [0, -1, 0], "Ctrl+Right": [0, 1, 0] } },
    { key: ["Ctrl+Up", "Ctrl+Down"], what: Words.year, moves: { "Ctrl+Up": [-1, 0, 0], "Ctrl+Down": [1, 0, 0] } },
    { key: "t", what: Words.today, clickable: true, moves: { t: null } },
    { key: "Return", what: Words.events, clickable: true }
  ]
  readonly property var legend: focused ? [{ key: ["Up", "Down"], what: Words.event }].concat(details ? [] : [{ key: "Return", what: Words.details }])
    : keys.filter(entry => entry.what)
  readonly property var help: keys.filter(entry => entry.desc)
  readonly property string error: Calendar.syncing ? "" : Calendar.error

  // Today, with no event in focus: how a calendar level opens.
  function reset() {
    select(new Date());
  }

  function select(day) {
    internal.selected = day;
    clearFocus();
  }

  function focus(row) {
    internal.focused = row.id;
    internal.selected = row.day;
    internal.details = false;
    internal.unfolded = internal.unfolded || Calendar.earlier(row);
  }

  function clearFocus() {
    internal.focused = "";
    internal.details = false;
    internal.unfolded = false;
  }

  // Escape's step within the level: the details, then the focus; false with neither to leave.
  function stepBack() {
    if (details) internal.details = false;
    else if (focused) clearFocus();
    else return false;
    return true;
  }

  // Whether the key was a calendar key, acting on it: Return focuses events, then shows the focused one whole; arrows step them; Escape steps back (MenuModel.stepBack).
  function handleKey(name) {
    const rows = Calendar.timeline;
    const at = focused ? rows.findIndex(row => row.id === focused) : -1;
    if (name === "Return") {
      const first = Calendar.firstOn(rows, Clock.dayKey(selected));
      if (at >= 0) internal.details = true;
      else if (first >= 0) focus(rows[first]);
      return true;
    }
    if (at >= 0 && (name === "Up" || name === "Down")) {
      focus(rows[Math.min(Math.max(at + (name === "Up" ? -1 : 1), 0), rows.length - 1)]);
      return true;
    }
    const entry = keys.find(entry => entry.moves && MenuKeys.matches(entry.key, name));
    if (!entry) return false;
    const move = entry.moves[name];
    if (move) moveSelected(...move);
    else reset();
    return true;
  }

  function moveSelected(years, months, days) {
    select(Clock.moved(selected, years, months, days));
  }

  readonly property QtObject internal: QtObject {
    property var selected: new Date()
    property string focused: ""
    property bool details: false
    property bool unfolded: false
  }
}
