pragma Singleton

import QtQuick
import Quickshell

// Which Panel opened last, so opening one dismisses the other; the top level's right slot, which the menu registers for a plugin's panel's bar.
Singleton {
  property var current: null
  property Component statuses: null
}
