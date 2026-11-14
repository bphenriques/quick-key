import QtQuick
import Quickshell
import Quickshell.Io

// A plugin's state from one source (docs/src/plugins.md): `watch` runs for as long as it lasts, each line replacing the
// state; `read` runs on refresh(), its last line replacing it; `file` is read again whenever the file changes. A line is
// a JSON object, or else plain text; an empty one clears the state.
Scope {
  id: root

  property string watch
  property string read
  // A path; a relative one is under $XDG_RUNTIME_DIR.
  property string file
  // The last good state: glyph, text, detail, active, tone and items, each optional.
  property var state: ({})

  function refresh() {
    reader.refresh();
  }

  function apply(line) {
    if (!line) {
      state = {};
      return;
    }
    if (!line.startsWith("{")) {
      state = { text: line };
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
    onRunningChanged: if (!running && root.watch) root.state = {}
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
    onLoadFailed: root.state = {}
  }
}
