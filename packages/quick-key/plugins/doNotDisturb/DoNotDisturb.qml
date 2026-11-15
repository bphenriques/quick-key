import QtQuick
import qs
import qs.ui

// Whether notifications are paused: the source gives `true` or `false` (or `active`), `activate` toggles them.
Plugin {
  readonly property bool paused: state.active ?? state.text === "true"

  glyph: paused ? Glyphs.doNotDisturb : Glyphs.notifications
  active: paused
  tone: paused ? "alert" : ""

  function activate() {
    exec(settings.activate);
  }
}
