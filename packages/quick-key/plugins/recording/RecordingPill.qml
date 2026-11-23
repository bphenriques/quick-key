import QtQuick
import QtQuick.Layouts
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

  RowLayout {
    spacing: Config.theme.spacing

    // The record dot; it squares into a stop button on hover.
    Rectangle {
      implicitWidth: Config.theme.iconSize / 3
      implicitHeight: implicitWidth
      radius: pill.hovered ? width / 4 : width / 2
      color: Tone.color("alert")
    }

    // Padded to the time's width (the font is monospace), so the pill keeps its size under the pointer.
    Label {
      text: pill.hovered ? pill.plugin.words.stop.padEnd(pill.plugin.shownTime.length) : pill.plugin.shownTime
    }

    Icon {
      tone: pill.plugin.micLive ? "alert" : "dim"
      glyph: pill.plugin.micLive ? Glyphs.microphone : Glyphs.microphoneOff
    }
  }
}
