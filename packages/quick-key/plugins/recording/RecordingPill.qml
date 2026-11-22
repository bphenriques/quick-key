import QtQuick
import qs
import qs.services
import qs.ui

// The pill on every screen while recording: the time, the mic, and a click to stop.
CornerPill {
  id: pill

  required property var plugin

  shown: pill.plugin.recording
  tone: "alert"
  namespace: "recording-indicator"
  onClicked: pill.plugin.exec(pill.plugin.settings.stop)

  Row {
    spacing: Config.theme.spacing

    // The record dot; it squares into a stop button on hover.
    Rectangle {
      anchors.verticalCenter: parent.verticalCenter
      width: Config.theme.iconSize / 3
      height: width
      radius: pill.hovered ? width / 4 : width / 2
      color: Tone.color("alert")
    }

    // Padded to the time's width (the font is monospace), so the pill keeps its size under the pointer.
    Label {
      anchors.verticalCenter: parent.verticalCenter
      text: pill.hovered ? pill.plugin.words.stop.padEnd(pill.plugin.shownTime.length) : pill.plugin.shownTime
    }

    Icon {
      anchors.verticalCenter: parent.verticalCenter
      tone: pill.plugin.micLive ? "alert" : "dim"
      glyph: pill.plugin.micLive ? Glyphs.microphone : Glyphs.microphoneOff
    }
  }
}
