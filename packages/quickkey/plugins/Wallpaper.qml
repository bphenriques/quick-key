import QtQuick
import qs
import qs.services
import qs.ui

// The wallpaper last set, by name: its state's text (watch, read or file) is the wallpaper's path or name.
Plugin {
  id: root

  glyph: Glyphs.wallpaper
  text: (command.state.text ?? "").replace(/^.*\//, "").replace(/\.[^.]+$/, "")

  function refresh() {
    command.refresh();
  }

  CommandState {
    id: command
    watch: root.settings.watch ?? ""
    read: root.settings.read ?? ""
    file: root.settings.file ?? ""
  }
}
