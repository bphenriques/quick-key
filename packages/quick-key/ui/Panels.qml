pragma Singleton

import Quickshell

// Which Panel opened last, so opening one dismisses the other.
Singleton {
  property var current: null
}
