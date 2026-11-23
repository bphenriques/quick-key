pragma Singleton

import QtQuick
import Quickshell
import qs.services

// What a level's `view` shows in place of a menu, by name, each given its model (MenuModel's, as the surfaces own them): its keys beyond the rows (legend), why its source failed, its own keys, what Escape closes first, and its state as a level opens or comes back.
Singleton {
  readonly property var builtin: Object.assign(Object.create(null), {
    calendar: {
      legend: model => model.legend,
      error: () => Calendar.syncing ? "" : Calendar.error,
      handleKey: (model, name) => model.handleKey(name),
      // A focused event's details, then the focus, before the level.
      stepBack: model => model.stepBack(),
      reset: model => model.reset(),
      clear: model => model.clearFocus()
    }
  })
}
