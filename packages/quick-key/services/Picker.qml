pragma Singleton

import QtQuick
import Quickshell

// Asks the menu for a list by name (Lists), filtered in place on a level of its own: what a plugin's panel opens (Ask's C-r), over it, so Escape shows the panel again (Panels).
Singleton {
  signal requested(string list)

  function pick(name) {
    requested(name);
  }
}
