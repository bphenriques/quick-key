import QtQuick
import Quickshell.Io
import qs

// A plugin made of commands, under any name (`type = "command"`); see docs/src/plugins.md.
Plugin {
  id: root

  function activate() {
    exec(settings.activate);
  }

  // Read again once it is done, so the item now in use lights.
  function select(id) {
    if (!settings.select) return;
    selector.command = commandLine(settings.select, id);
    selector.running = true;
  }

  Process {
    id: selector
    onExited: root.refresh()
  }
}
