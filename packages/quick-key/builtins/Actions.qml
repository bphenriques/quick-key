pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// The built-in actions by name; an entry's `action` names one in place of `cmd`, its icon and lit state overridable.
Singleton {
  // Each: run(second), told whether a pair's second key was pressed; available(); its icon; the state lighting it; pair.
  readonly property var builtin: ({
    sinkVolume: { pair: true, icon: Glyphs.volume, available: () => Audio.sink !== null, run: up => Audio.adjust("sink", up) },
    sinkMute: { icon: Glyphs.volumeOff, state: "sinkMuted", available: () => Audio.sink !== null, run: () => Audio.toggleMute("sink") },
    sourceVolume: { pair: true, icon: Glyphs.microphone, available: () => Audio.source !== null, run: up => Audio.adjust("source", up) },
    sourceMute: { icon: Glyphs.microphoneOff, state: "sourceMuted", available: () => Audio.source !== null, run: () => Audio.toggleMute("source") },
    wifi: { icon: Glyphs.power, state: "wifi", available: () => Network.wifiPresent, run: () => Network.toggleWifi() },
    bluetooth: { icon: Glyphs.power, state: "bluetooth", available: () => Bluez.present, run: () => Bluez.toggle() },
    playPause: { icon: Glyphs.playPause, available: () => Music.present, run: () => Music.togglePlaying() },
    track: { pair: true, icon: Glyphs.track, available: () => Music.present, run: forward => Music.skip(forward) },
    repeat: { icon: Glyphs.repeat, state: "repeat", available: () => Music.present, run: () => Music.toggleRepeat() },
    shuffle: { icon: Glyphs.shuffle, state: "shuffle", available: () => Music.present, run: () => Music.toggleShuffle() },
    keepAwake: { icon: Glyphs.keepAwake, state: "keepAwake", available: () => true, run: () => IdleInhibit.toggle() },
    keyboardLayout: { icon: Glyphs.keyboard, available: () => KeyboardLayout.names.length > 1, run: () => KeyboardLayout.next() }
  })
}
