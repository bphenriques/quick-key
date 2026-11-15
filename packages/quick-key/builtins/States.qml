pragma Singleton

import QtQuick
import Quickshell
import qs.services

// The built-in states by name; `activeWhen` names one of these or a plugin.
Singleton {
  readonly property var builtin: ({
    wifi: () => Network.wifiEnabled,
    bluetooth: () => Bluez.enabled,
    repeat: () => Music.repeat,
    shuffle: () => Music.shuffle,
    "sink-muted": () => Audio.sinkMuted,
    "source-muted": () => Audio.sourceMuted,
    "keep-awake": () => IdleInhibit.enabled
  })
}
