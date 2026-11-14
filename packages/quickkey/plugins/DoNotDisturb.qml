import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Whether notifications are paused, from the notification daemon's commands: `watch` or `read` prints `true` or `false`
// (or a state line with `active`), `activate` pauses or resumes them.
Plugin {
  id: root

  readonly property bool paused: command.state.active ?? command.state.text === "true"

  glyph: paused ? Glyphs.doNotDisturb : Glyphs.notifications
  active: paused
  tone: paused ? "alert" : ""
  shortcut: settings.shortcut ?? ""

  function activate() {
    exec(settings.activate);
  }

  function refresh() {
    command.refresh();
  }

  CommandState {
    id: command
    watch: root.settings.watch ?? ""
    read: root.settings.read ?? ""
    file: root.settings.file ?? ""
  }

  IpcHandler {
    target: root.name

    function toggle(): void {
      root.activate();
    }

    function refresh(): void {
      root.refresh();
    }
  }
}
