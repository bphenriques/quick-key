import QtQuick
import qs.services
import qs.ui

// A calendar level's state: the selected day, the event in focus, and the keys that move them (docs/src/calendar.md).
QtObject {
  id: root

  property var selected: new Date()
  // The event in focus, by its row id in Calendar.timeline, so a new read of the file keeps it; "" while the keys move the day.
  property string focused: ""

  readonly property string title: Clock.locale.standaloneMonthName(selected.getMonth()) + " " + selected.getFullYear()
  // Each moves the selected day by [years, months, days], or back to today (null); the arrows go unlisted, the grid shows them.
  readonly property var keys: [
    { key: ["Left", "Right"], what: "day", unlisted: true, moves: { Left: [0, 0, -1], Right: [0, 0, 1] } },
    { key: ["Up", "Down"], what: "week", unlisted: true, moves: { Up: [0, 0, -7], Down: [0, 0, 7] } },
    { key: ["Ctrl+Left", "Ctrl+Right"], what: "month", moves: { "Ctrl+Left": [0, -1, 0], "Ctrl+Right": [0, 1, 0] } },
    { key: ["Ctrl+Up", "Ctrl+Down"], what: "year", moves: { "Ctrl+Up": [-1, 0, 0], "Ctrl+Down": [1, 0, 0] } },
    { key: "t", what: "today", clickable: true, moves: { t: null } },
    { key: "Return", what: "events", clickable: true }
  ]
  readonly property var eventKeys: [{ key: ["Up", "Down"], what: "event" }, { key: "BackSpace", what: "back", clickable: true }]
  // Shown under the header (KeyLegend).
  readonly property var legend: focused ? eventKeys : keys.filter(entry => !entry.unlisted)

  // Today, with no event in focus: how a calendar level opens.
  function reset() {
    select(new Date());
  }

  function select(day) {
    selected = day;
    focused = "";
  }

  function focus(row) {
    focused = row.id;
    selected = row.day;
  }

  // Whether the key was a calendar key, acting on it: Return focuses events, arrows step them, Backspace leaves.
  function handleKey(name) {
    const rows = Calendar.timeline;
    const at = focused ? rows.findIndex(row => row.id === focused) : -1;
    if (name === "Return") {
      const first = rows.find(row => row.key >= Calendar.key(selected));
      if (first) focus(first);
      return true;
    }
    if (at >= 0 && (name === "Up" || name === "Down")) {
      focus(rows[Math.min(Math.max(at + (name === "Up" ? -1 : 1), 0), rows.length - 1)]);
      return true;
    }
    if (focused && name === "BackSpace") {
      focused = "";
      return true;
    }
    const entry = keys.find(entry => entry.moves && MenuKeys.matches(entry.key, name));
    if (!entry) return false;
    const move = entry.moves[name];
    if (move) moveSelected(...move);
    else reset();
    return true;
  }

  // A month or year away keeps the day, or the month's last when it has fewer.
  function moveSelected(years, months, days) {
    const year = selected.getFullYear() + years;
    const month = selected.getMonth() + months;
    const last = new Date(year, month + 1, 0).getDate();
    select(new Date(year, month, Math.min(selected.getDate(), last) + days));
  }
}
