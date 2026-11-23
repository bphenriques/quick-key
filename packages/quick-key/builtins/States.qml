pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Built-in states by name, for `activeWhen`; no prototype, as in Statuses.qml.
Singleton {
  readonly property var builtin: Object.assign(Object.create(null), {
    wifi: () => Network.wifiEnabled,
    bluetooth: () => Bluez.enabled,
    repeat: () => Music.repeat,
    shuffle: () => Music.shuffle,
    sinkMuted: () => Audio.sinkMuted,
    sourceMuted: () => Audio.sourceMuted,
    streamMuted: () => Audio.streamMuted,
    keepAwake: () => KeepAwake.enabled
  })
}
