pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Whether the screen is kept awake (widgets/KeepAwakeInhibitor holds Wayland's idle inhibitor while it is); on until switched off, a reload or restart included (Kept).
Singleton {
  id: root

  readonly property bool enabled: kept.value ?? false

  KeptValue {
    id: kept
    key: "keepAwake"
  }

  function toggle() {
    Kept.set("keepAwake", !enabled);
  }

  IpcHandler {
    target: "keepAwake"

    function toggle(): void {
      root.toggle();
    }
  }
}
