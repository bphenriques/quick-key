pragma Singleton

import QtQuick
import Quickshell

// The backend without a compositor of its own: Wayland's screens, each on, no layouts, Wayland placing pop-ups.
Singleton {
  readonly property var layouts: []
  readonly property int layoutIndex: 0
  readonly property string focusedOutput: ""

  function outputs(then) {
    const names = Quickshell.screens.map(screen => screen.name);
    then(names, names);
  }

  function switchLayout() {
  }
}
