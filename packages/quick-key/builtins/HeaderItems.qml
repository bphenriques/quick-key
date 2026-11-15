pragma Singleton

import QtQuick
import Quickshell
import qs.services

// The header's built-in items by name; `menu.header` names one of these or a plugin.
Singleton {
  // Each: shown(), and optionally activate(menu) for a click, enabled(menu), and a label() in place of its status.
  readonly property var builtin: ({
    clock: {
      shown: () => true,
      label: () => Clock.text,
      enabled: menu => menu.calendarEntry !== null,
      activate: menu => menu.activate(menu.calendarEntry)
    },
    keepAwake: { shown: () => true, activate: () => IdleInhibit.toggle() },
    keyboardLayout: { shown: () => KeyboardLayout.names.length > 0, activate: () => KeyboardLayout.next() },
    // State only.
    battery: { shown: () => Power.present }
  })
}
