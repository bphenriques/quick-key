pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What you chose while you are logged in (keep awake on, a draft, a list's order, a conversation), by key, kept over a reload or a restart (a deploy).
Singleton {
  readonly property var values: internal.values

  function set(key, value) {
    internal.values = Object.assign({}, internal.values, { [key]: value });
    write.restart();
  }

  // Written once typing or a streamed answer pauses, not on each key; and before a reload replaces it.
  Timer {
    id: write
    interval: 500
    onTriggered: file.setText(JSON.stringify(internal.values))
  }

  Component.onDestruction: if (write.running) file.setText(JSON.stringify(internal.values))

  // Read before anyone reads it, so a value is never set over one still loading.
  Component.onCompleted: {
    try {
      const values = JSON.parse(file.text() || "{}");
      internal.values = values && typeof values === "object" && !Array.isArray(values) ? values : {};
    } catch (error) {
      internal.values = {};
    }
  }

  // In the runtime dir, which a new session starts empty; by shell, so a preview or a test never writes the running one's.
  FileView {
    id: file
    path: `${Quickshell.env("XDG_RUNTIME_DIR")}/quick-key/${Quickshell.shellId}.json`
    blockLoading: true
    printErrors: false
  }

  QtObject {
    id: internal
    property var values: ({})
  }
}
