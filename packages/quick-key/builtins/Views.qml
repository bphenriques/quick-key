pragma Singleton

import QtQuick
import Quickshell

// What a level's `view` shows in place of a menu, by name: its model and its view, files beside LevelModel, which makes the model as its level first shows and gives it to the view. A model has keys (each it takes, listed on `?` by its desc), legend (its keys beyond the rows), error (why its source failed), handleKey(name), stepBack() (what Escape closes first, false for none), reset() as its level opens and clearFocus() as any level comes or goes.
Singleton {
  readonly property var builtin: Object.assign(Object.create(null), {
    calendar: { model: "calendar/CalendarModel.qml", source: "CalendarView.qml" }
  })
}
