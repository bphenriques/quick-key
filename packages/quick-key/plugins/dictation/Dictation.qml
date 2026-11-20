pragma ComponentBehavior: Bound

import QtQuick
import qs

// Whether dictation listens or transcribes; DictationPill.qml draws it.
Plugin {
  id: root

  // `recording`, `transcribing` or else idle, from the source or the `phase` its `show` gives the value.
  readonly property string phase: state.phase ?? state.value ?? ""
  readonly property bool recording: phase === "recording"
  readonly property bool transcribing: phase === "transcribing"

  active: recording || transcribing
  views: ["DictationPill.qml"]
}
