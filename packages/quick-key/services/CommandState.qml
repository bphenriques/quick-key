import QtQuick
import Quickshell
import Quickshell.Io

// A plugin's state from its one source: watch, read or file (docs/src/plugins.md#sources); a plain line is its `value`.
Scope {
  id: root

  property string watch
  property string read
  // A path; a relative one is under $XDG_RUNTIME_DIR.
  property string file
  // The last good state: glyph, text, detail, active, tone and items, each optional.
  property var state: ({})

  QtObject {
    id: internal
    property string line: ""
  }

  function refresh() {
    reader.refresh();
  }

  // A line the same as the last changes nothing: watchers repeat themselves, and a new state rebuilds what lists it.
  function apply(line) {
    if (line === internal.line) return;
    internal.line = line;
    if (!line) {
      state = {};
      return;
    }
    if (!line.startsWith("{")) {
      state = { value: line };
      return;
    }
    try {
      const value = JSON.parse(line);
      if (value !== null && typeof value === "object" && !Array.isArray(value)) state = value;
      else console.warn("not a JSON object, ignored:", line);
    } catch (error) {
      console.warn("not JSON, ignored:", line);
    }
  }

  function lastLine(text) {
    return text.trim().split("\n").pop().trim();
  }

  // Its state lasts as long as it runs, so a command that dies leaves nothing stale on screen.
  CommandWatcher {
    shell: root.watch
    onRead: line => root.apply(line.trim())
    onRunningChanged: if (!running && root.watch) root.apply("")
  }

  CommandReader {
    id: reader
    shell: root.read
    atStart: true
    onRead: text => root.apply(root.lastLine(text))
  }

  FileView {
    path: !root.file ? "" : root.file.startsWith("/") ? root.file : Quickshell.env("XDG_RUNTIME_DIR") + "/" + root.file
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: root.apply(root.lastLine(text()))
    onLoadFailed: root.apply("")
  }
}
