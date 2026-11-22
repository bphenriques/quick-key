pragma Singleton

import QtQuick
import Quickshell
import qs.services

// The built-in states by name; `activeWhen` names one of these or a plugin; a table without a prototype, so no name every object inherits (toString) is one.
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
