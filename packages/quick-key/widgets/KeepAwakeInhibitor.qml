import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.ui

// Wayland's idle inhibitor while KeepAwake is on, which the compositor holds for every idle daemon (hypridle, swayidle); the protocol inhibits through a surface: one pixel, transparent, taking no input, there only while on.
Scope {
  IdleInhibitor {
    enabled: KeepAwake.enabled
    // On the overlay layer: niri honours an inhibitor only while its surface is drawn, which a fullscreen window stops on the top layer.
    window: OverlayWindow {
      visible: KeepAwake.enabled
      implicitWidth: 1
      implicitHeight: 1
      mask: Region {}
      WlrLayershell.namespace: "quick-key-keep-awake"
    }
  }
}
