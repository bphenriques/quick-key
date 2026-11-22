pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What you chose while you are logged in (keep awake on, a draft, a list's order, a conversation), by key, kept over a reload or a restart (a deploy).
Singleton {
  readonly property var values: internal.values

  function set(key, value) {
    internal.values = Object.assign({}, internal.values, { [key]: value });
    file.setText(JSON.stringify(internal.values));
  }

  // Read before anyone reads it, so a value is never set over one still loading.
  Component.onCompleted: {
    try {
      internal.values = JSON.parse(file.text() || "{}");
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
