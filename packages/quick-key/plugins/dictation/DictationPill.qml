import QtQuick
import qs
import qs.services
import qs.ui

// The pill on every screen while dictating: its icon while it listens, a spinner while it transcribes.
CornerPill {
  id: pill

  required property var plugin

  shown: pill.plugin.active
  namespace: "dictation-indicator"
  onClicked: pill.plugin.exec(pill.plugin.settings.stop)

  Icon {
    busy: pill.plugin.transcribing
    tone: Audio.sourceMuted && !busy ? "dim" : "normal"
    glyph: pill.plugin.glyph
  }
}
