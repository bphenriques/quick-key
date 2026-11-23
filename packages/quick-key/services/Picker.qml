pragma Singleton

import QtQuick
import Quickshell

// Asks the menu for a list by name, filtered on a level of its own over the plugin panel that asked (Ask C-r), so Escape shows the panel again.
Singleton {
  signal requested(string list)

  function pick(name) {
    requested(name);
  }
}
