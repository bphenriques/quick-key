import QtQuick
import Quickshell
import Quickshell.Wayland
import qs.services
import qs.ui

// Wayland's idle inhibitor while KeepAwake is on; the protocol inhibits through a surface, here one transparent pixel taking no input.
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
