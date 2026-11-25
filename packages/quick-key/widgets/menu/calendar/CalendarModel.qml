import QtQuick
import qs.services
import qs.ui
import qs.builtins

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
  readonly property var keys: Views.builtin.calendar.keys
  readonly property var legend: focused ? [{ key: ["Up", "Down"], what: Words.event }].concat(details ? [] : [{ key: "Return", what: Words.details }])
    : keys.filter(entry => entry.what)
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
