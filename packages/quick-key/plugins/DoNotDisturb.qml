import QtQuick
import qs
import qs.ui

// Whether notifications are paused, from the notification daemon's commands: `watch` or `read` prints `true` or `false`
// (or a state line with `active`), `activate` pauses or resumes them.
Plugin {
  readonly property bool paused: state.active ?? state.text === "true"

  glyph: paused ? Glyphs.doNotDisturb : Glyphs.notifications
  active: paused
  tone: paused ? "alert" : ""

  function activate() {
    exec(settings.activate);
  }
}
