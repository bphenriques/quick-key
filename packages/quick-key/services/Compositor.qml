pragma Singleton

import QtQuick
import Quickshell
import qs.services.compositor

// What the core asks of the compositor (docs/src/compositor.md), from one backend with the same few members: niri's, else Wayland's screens and no layouts.
Singleton {
  id: root

  readonly property string backend: Quickshell.env("NIRI_SOCKET") ? "niri" : ""
  readonly property var impl: backend === "niri" ? Niri : Wayland

  // Each output twice, by connector name and by make, model and serial: those connected, and those on. Read on refresh().
  readonly property var connected: internal.connected
  readonly property var enabled: internal.enabled
  readonly property var layouts: impl.layouts
  readonly property int layoutIndex: impl.layoutIndex
  // The output keys and pop-ups go to, by connector name; "" without a backend, Wayland placing them.
  readonly property string focusedOutput: impl.focusedOutput

  function refresh() {
    impl.outputs((connected, enabled) => {
      internal.connected = connected;
      internal.enabled = enabled;
    });
  }

  function nextLayout() {
    impl.switchLayout();
  }

  QtObject {
    id: internal
    property var connected: []
    property var enabled: []
  }
}
