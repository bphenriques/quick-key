pragma ComponentBehavior: Bound

import QtQuick
import qs

// Whether dictation listens or transcribes; DictationPill.qml draws it.
Plugin {
  id: root

  readonly property string phase: state.text ?? ""
  readonly property bool recording: phase === "recording"
  readonly property bool transcribing: phase === "transcribing"

  glyph: settings.glyph
  active: recording || transcribing
  views: ["DictationPill.qml"]
}
