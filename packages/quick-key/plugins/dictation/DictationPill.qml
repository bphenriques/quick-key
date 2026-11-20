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

  Item {
    implicitWidth: Config.theme.iconSize
    implicitHeight: Config.theme.iconSize

    Icon {
      anchors.fill: parent
      visible: !pill.plugin.transcribing
      tone: Audio.sourceMuted ? "dim" : "normal"
      glyph: pill.plugin.glyph
    }

    Spinner {
      anchors.fill: parent
      visible: pill.plugin.transcribing
      tone: "normal"
    }
  }
}
