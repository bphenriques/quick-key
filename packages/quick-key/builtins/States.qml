pragma Singleton

import QtQuick
import Quickshell
import qs.services

// Built-in states by name, for `activeWhen`; no prototype, as in Statuses.qml.
Singleton {
  readonly property var builtin: Object.assign(Object.create(null), {
    // Wi-Fi is on.
    wifi: () => Network.wifiEnabled,
    // Bluetooth is on.
    bluetooth: () => Bluez.enabled,
    // The player repeats.
    repeat: () => Music.repeat,
    // The player shuffles.
    shuffle: () => Music.shuffle,
    // The default output is muted.
    sinkMuted: () => Audio.sinkMuted,
    // The microphone is muted.
    sourceMuted: () => Audio.sourceMuted,
    // The app picked on the streams list is muted.
    streamMuted: () => Audio.streamMuted,
    // The screen is kept awake.
    keepAwake: () => KeepAwake.enabled
  })
}
