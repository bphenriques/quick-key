import QtQuick
import Quickshell.Io
import qs
import qs.services

// A plugin made of commands (docs/src/plugins.md), used under any name: `source = "command"`. `select` runs with the
// chosen item's id.
Plugin {
  id: root

  glyph: command.state.glyph ?? ""
  text: command.state.text ?? ""
  detail: command.state.detail ?? ""
  active: command.state.active ?? false
  tone: command.state.tone ?? ""
  items: command.state.items ?? []
  shortcut: settings.shortcut ?? ""

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

  function refresh() {
    command.refresh();
  }

  Component.onCompleted: if ([settings.watch, settings.read, settings.file].filter(source => source).length > 1) console.warn("plugin", name, "sets more than one of watch, read and file; set one");

  CommandState {
    id: command
    watch: root.settings.watch ?? ""
    read: root.settings.read ?? ""
    file: root.settings.file ?? ""
  }

  IpcHandler {
    target: root.name

    function refresh(): void {
      root.refresh();
    }
  }
}
