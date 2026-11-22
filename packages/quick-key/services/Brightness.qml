pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs

// The backlight's file and maximum come from Config.brightness.backlight; the file is watched, every write to it notifies.
Singleton {
  id: root

  readonly property bool present: internal.maximum > 0
  // The backlight directory's name, which is how logind addresses it.
  readonly property string name: internal.file.replace(/\/brightness$/, "").split("/").pop()
  // The panel it dims is on, as of the last time the menu opened.
  readonly property string panel: Config.brightness.panel || Compositor.connected.find(output => /^(eDP|LVDS|DSI)-/.test(output)) || ""
  readonly property bool lit: present && Compositor.enabled.includes(panel)
  readonly property int percentage: present ? Math.round(internal.current * 100 / internal.maximum) : 0

  // A step down or up, by Config.brightness.step, from the level last asked for while a write is under way; at least 1, so a panel with few levels still moves, and never below 1, which would turn the backlight off.
  function adjust(up) {
    const by = Math.max(1, Math.round(Config.brightness.step * internal.maximum / 100));
    const from = internal.wanted >= 0 ? internal.wanted : internal.current;
    internal.wanted = Math.max(1, Math.min(internal.maximum, from + (up ? by : -by)));
    if (!writer.running) writer.write();
  }

  QtObject {
    id: internal
    property string file: ""
    property int maximum: 0
    property int current: 0
    // The level asked for while a write is under way, else -1.
    property int wanted: -1
  }

  // One write at a time: steps taken meanwhile gather into the next, and a write that succeeded is the level before the file reports it.
  CommandProcess {
    id: writer
    property int writing: -1

    function write() {
      writing = internal.wanted;
      exec(Commands.line(Config.brightness.set, root.name, String(writing)));
    }

    onExited: code => {
      if (code === 0) internal.current = writing;
      if (internal.wanted !== writing) write();
      else internal.wanted = -1;
    }
  }

  CommandReader {
    shell: Config.brightness.backlight
    atStart: true
    onRead: text => {
      const [file, maximum] = text.trim().split("\t");
      internal.file = file ?? "";
      internal.maximum = parseInt(maximum) || 0;
    }
  }

  FileView {
    path: internal.file
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: internal.current = parseInt(text()) || 0
  }
}
