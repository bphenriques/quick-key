pragma Singleton

import QtQuick
import Quickshell
import qs.ui

// What a level's `view` shows in place of a menu, by name: its model and its view, files beside LevelModel, which makes the model as its level first shows and gives it to the view, and the keys it takes, which the key map and the check read. A model has keys (these), legend (its keys beyond the rows), error (why its source failed), handleKey(name), stepBack() (what Escape closes first, false for none), reset() as its level opens and clearFocus() as any level comes or goes.
Singleton {
  readonly property var builtin: Object.assign(Object.create(null), {
    // A month's grid beside the events of calendar.file from the day selected on it.
    calendar: {
      model: "calendar/CalendarModel.qml",
      source: "CalendarView.qml",
      // Each moves the selected day by [years, months, days], or back to today (null); the arrows, which the grid shows, and the year are listed on `?` (desc), the rest in the legend (what).
      keys: [
        { key: ["Left", "Right"], paired: true, desc: Words.helpDay, moves: { Left: [0, 0, -1], Right: [0, 0, 1] } },
        { key: ["Up", "Down"], paired: true, desc: Words.helpWeek, moves: { Up: [0, 0, -7], Down: [0, 0, 7] } },
        { key: ["Ctrl+Left", "Ctrl+Right"], what: Words.month, moves: { "Ctrl+Left": [0, -1, 0], "Ctrl+Right": [0, 1, 0] } },
        { key: ["Ctrl+Up", "Ctrl+Down"], paired: true, desc: Words.helpYear, moves: { "Ctrl+Up": [-1, 0, 0], "Ctrl+Down": [1, 0, 0] } },
        { key: "t", what: Words.today, clickable: true, moves: { t: null } },
        { key: "Return", what: Words.events, clickable: true }
      ]
    }
  })
}
