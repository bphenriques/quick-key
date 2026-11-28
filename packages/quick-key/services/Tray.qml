pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.SystemTray
import "tray.js" as Lib

// Apps' tray icons (StatusNotifierItem). Apps register only with a running host, so this is created at startup.
Singleton {
  readonly property var items: Array.from(SystemTray.items.values).sort((a, b) => (a.title || a.id).localeCompare(b.title || b.id))

  function shown(hide) {
    return Lib.shown(items, hide);
  }

  // Each icon looked up as it registers or changes, so the menu never waits on the theme's first lookup of a name, which Qt then keeps.
  Instantiator {
    model: SystemTray.items

    Image {
      required property SystemTrayItem modelData
      source: modelData.icon
      sourceSize: Qt.size(1, 1)
    }
  }
}
