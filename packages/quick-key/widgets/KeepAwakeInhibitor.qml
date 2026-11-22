import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services

// Wayland's idle inhibitor while KeepAwake is on, which the compositor holds for every idle daemon (hypridle, swayidle); the protocol inhibits through a surface: one pixel, transparent, taking no input, there only while on.
Scope {
  IdleInhibitor {
    enabled: KeepAwake.enabled
    window: PanelWindow {
      visible: KeepAwake.enabled
      implicitWidth: 1
      implicitHeight: 1
      color: "transparent"
      mask: Region {}
      exclusionMode: ExclusionMode.Ignore
      WlrLayershell.namespace: "quick-key-keep-awake"
    }
  }
}
