pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// Whether a screen recording runs, and for how long; RecordingPill.qml draws it.
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
  views: ["RecordingPill.qml"]

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
}
