pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// The built-in actions by name; an entry's `action` names one in place of `cmd`, its icon and lit state overridable.
Singleton {
  // Each: run(second), told whether a pair's second key was pressed; available(); its icon; the state lighting it; pair.
  readonly property var builtin: ({
    "sink-volume": { pair: true, icon: Glyphs.volume, available: () => Audio.sink !== null, run: up => Audio.adjust("sink", up) },
    "sink-mute": { icon: Glyphs.volumeOff, state: "sink-muted", available: () => Audio.sink !== null, run: () => Audio.toggleMute("sink") },
    "source-volume": { pair: true, icon: Glyphs.microphone, available: () => Audio.source !== null, run: up => Audio.adjust("source", up) },
    "source-mute": { icon: Glyphs.microphoneOff, state: "source-muted", available: () => Audio.source !== null, run: () => Audio.toggleMute("source") },
    wifi: { icon: Glyphs.power, state: "wifi", available: () => Network.wifiPresent, run: () => Network.toggleWifi() },
    bluetooth: { icon: Glyphs.power, state: "bluetooth", available: () => Bluez.present, run: () => Bluez.toggle() },
    "play-pause": { icon: Glyphs.playPause, available: () => Music.present, run: () => Music.togglePlaying() },
    track: { pair: true, icon: Glyphs.track, available: () => Music.present, run: forward => Music.skip(forward) },
    repeat: { icon: Glyphs.repeat, state: "repeat", available: () => Music.present, run: () => Music.toggleRepeat() },
    shuffle: { icon: Glyphs.shuffle, state: "shuffle", available: () => Music.present, run: () => Music.toggleShuffle() },
    "keep-awake": { icon: Glyphs.keepAwake, state: "keep-awake", available: () => true, run: () => IdleInhibit.toggle() },
    "keyboard-layout": { icon: Glyphs.keyboard, available: () => KeyboardLayout.names.length > 1, run: () => KeyboardLayout.next() }
  })
}
