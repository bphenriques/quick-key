pragma ComponentBehavior: Bound

import QtQuick
import qs

// Whether dictation listens or transcribes; DictationPill.qml draws it.
Plugin {
  id: root

  // `recording`, `transcribing` or else idle, from the source or the `stage` its `show` gives the value; `phase` is every plugin's work (Phase).
  readonly property string stage: state.stage ?? state.value ?? ""
  readonly property bool recording: stage === "recording"
  readonly property bool transcribing: stage === "transcribing"

  active: recording || transcribing
  views: ["DictationPill.qml"]
}
