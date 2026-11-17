pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// A level's whole list in Config.menu.picker, a dmenu-like command: a line per item in, the chosen line out, which then runs as its digit would.
Singleton {
  id: root

  property var items: []

  // Its icon when a glyph, its label and its detail: what the row shows, as text.
  function line(item) {
    return [item.icon, item.desc, item.detail].filter(part => part).join("  ");
  }

  function pick(list) {
    if (!Config.menu.picker || picker.running) return;
    items = list;
    picker.running = true;
  }

  Process {
    id: picker
    command: ["sh", "-c", Config.menu.picker]
    stdinEnabled: true
    // Closed once written, as a picker reads to the end before it shows.
    onStarted: {
      write(root.items.map(root.line).join("\n") + "\n");
      stdinEnabled = false;
    }
    onExited: stdinEnabled = true

    stdout: StdioCollector {
      onStreamFinished: {
        const item = root.items.find(item => root.line(item) === text.trim());
        if (item) item.select();
      }
    }
  }
}
