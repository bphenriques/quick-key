pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The built-in actions by name; an entry's `action` names one in place of `cmd`, its icon and lit state overridable.
Singleton {
  // Each: run(second, list, menu), told whether a pair's second key was pressed, given its level's list and the menu; detail(list), a value beside it; available(list); icon(), showing its state where it has one; the state lighting it; pair; closes, to hide the menu first.
  readonly property var builtin: ({
    sinkVolume: { pair: true, icon: () => Glyphs.volume, available: () => Audio.sink !== null, run: up => Audio.adjust("sink", up) },
    sinkMute: { icon: () => Glyphs.volumeOff, state: "sinkMuted", available: () => Audio.sink !== null, run: () => Audio.toggleMute("sink") },
    sourceVolume: { pair: true, icon: () => Glyphs.microphone, available: () => Audio.source !== null, run: up => Audio.adjust("source", up) },
    brightness: { pair: true, icon: () => Glyphs.brightnessLevels[1], available: () => Brightness.lit, run: up => Brightness.adjust(up) },
    sourceMute: { icon: () => Glyphs.microphoneOff, state: "sourceMuted", available: () => Audio.source !== null, run: () => Audio.toggleMute("source") },
    wifi: { icon: () => Network.wifiEnabled ? Glyphs.wifi : Glyphs.disconnected, state: "wifi", available: () => Network.wifiPresent, run: () => Network.toggleWifi() },
    bluetooth: { icon: () => Bluez.enabled ? Glyphs.bluetooth : Glyphs.bluetoothOff, state: "bluetooth", available: () => Bluez.present, run: () => Bluez.toggle() },
    playPause: { icon: () => Glyphs.playPause, available: () => Music.present, run: () => Music.togglePlaying() },
    track: { pair: true, icon: () => Glyphs.track, available: () => Music.present, run: forward => Music.skip(forward) },
    repeat: { icon: () => Glyphs.repeat, state: "repeat", available: () => Music.present, run: () => Music.toggleRepeat() },
    shuffle: { icon: () => Glyphs.shuffle, state: "shuffle", available: () => Music.present, run: () => Music.toggleShuffle() },
    keepAwake: { icon: () => Glyphs.keepAwake, state: "keepAwake", available: () => true, run: () => IdleInhibit.toggle() },
    keyboardLayout: { icon: () => Glyphs.keyboard, available: () => KeyboardLayout.names.length > 1, run: () => KeyboardLayout.next() },
    // Filters the level's list in place; beside it, the nine rows at rest of all it can show, when there are more (1-9 of 14).
    pick: {
      icon: () => Glyphs.search,
      available: list => list.length > 0,
      detail: list => {
        const shown = list.filter(item => !item.hidden).length;
        return shown > 9 ? "1-9 of " + shown : "";
      },
      run: (second, list, menu) => menu.startFilter()
    }
  })
}
