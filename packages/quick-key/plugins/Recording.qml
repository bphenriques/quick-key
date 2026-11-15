pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// A pill on every screen while recording, a click stops it; its settings are in docs/src/plugins.md.
Plugin {
  id: root

  property int now: 0
  readonly property bool recording: state.active ?? false
  readonly property int startedAt: state.since ?? 0
  readonly property int elapsed: startedAt ? Math.max(0, now - startedAt) : 0
  // The recording mix includes the default mic whenever it is unmuted.
  readonly property bool micLive: !Audio.sourceMuted

  glyph: Glyphs.record
  text: recording ? Math.floor(elapsed / 60) + ":" + String(elapsed % 60).padStart(2, "0") : ""
  active: recording

  // The time the pill shows, kept while it fades out so it holds its size.
  property string shownTime: ""
  onTextChanged: if (recording) shownTime = text

  Timer {
    interval: 1000
    running: root.recording
    repeat: true
    triggeredOnStart: true
    onTriggered: root.now = Math.floor(Date.now() / 1000)
  }

  CornerPill {
    id: pill
    shown: root.recording
    tone: "alert"
    namespace: "recording-indicator"
    onClicked: root.exec(root.settings.stop)

    Row {
      spacing: Config.theme.spacing

      // The record dot; it squares into a stop button on hover.
      Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: Config.theme.iconSize / 3
        height: width
        radius: pill.hovered ? Config.theme.borderWidth * 2 : width / 2
        color: Tone.color("alert")
      }

      // Padded to the time's width (the font is monospace), so the pill keeps its size under the pointer.
      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: pill.hovered ? "Stop".padEnd(root.shownTime.length) : root.shownTime
      }

      Icon {
        anchors.verticalCenter: parent.verticalCenter
        tone: root.micLive ? "alert" : "dim"
        glyph: root.micLive ? Glyphs.microphone : Glyphs.microphoneOff
      }
    }
  }
}
