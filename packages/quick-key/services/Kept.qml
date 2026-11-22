pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// What you chose while you are logged in (keep awake on, a draft, a list's order, a conversation), by key, kept over a reload or a restart (a deploy). A binding reads one through a KeptValue, which wakes only when its own key changes.
Singleton {
  signal changed(string key)

  function value(key) {
    return internal.values[key];
  }

  function set(key, value) {
    if (internal.values[key] === value) return;
    internal.values[key] = value;
    changed(key);
    if (write.running) internal.dirty = true;
    else internal.save();
  }

  // Written at once, then at most twice a second: a choice is kept right up to a restart, and typing or a streamed answer costs a write each half second, not one a key.
  Timer {
    id: write
    interval: 500
    onTriggered: if (internal.dirty) internal.save()
  }

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
    property bool dirty: false

    function save() {
      dirty = false;
      file.setText(JSON.stringify(values));
      write.start();
    }
  }
}
