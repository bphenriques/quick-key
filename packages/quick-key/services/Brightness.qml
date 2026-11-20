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

  // A step down or up, by Config.brightness.step; a step of at least 1 still moves a panel with few levels, and a floor of 1 never turns the backlight off.
  function adjust(up) {
    const by = Math.max(1, Math.round(Config.brightness.step * internal.maximum / 100));
    const value = Math.max(1, Math.min(internal.maximum, internal.current + (up ? by : -by)));
    Commands.run(Config.brightness.set, name, String(value));
  }

  QtObject {
    id: internal
    property string file: ""
    property int maximum: 0
    property int current: 0
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
