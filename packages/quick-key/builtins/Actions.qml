pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// Built-in actions by name, run in place of an entry's `cmd`; no prototype, as in Statuses.qml.
Singleton {
  // Each: run(second, list, menu), told whether a pair's second key was pressed, given its level's list and the menu; detail(list), a value beside it; available(list); icon(), showing its state where it has one; the state lighting it; pair; closes, to hide the menu first.
  readonly property var builtin: Object.assign(Object.create(null), {
    sinkVolume: { pair: true, icon: () => Glyphs.volume, available: () => Audio.sink !== null, run: up => Audio.adjust(Audio.sink, up) },
    sinkMute: { icon: () => Glyphs.volumeOff, state: "sinkMuted", available: () => Audio.sink !== null, run: () => Audio.toggleMute(Audio.sink) },
    sourceVolume: { pair: true, icon: () => Glyphs.microphone, available: () => Audio.source !== null, run: up => Audio.adjust(Audio.source, up) },
    brightness: { pair: true, icon: () => Glyphs.brightnessLevels[1], available: () => Brightness.lit, run: up => Brightness.adjust(up) },
    sourceMute: { icon: () => Glyphs.microphoneOff, state: "sourceMuted", available: () => Audio.source !== null, run: () => Audio.toggleMute(Audio.source) },
    streamVolume: { pair: true, icon: () => Glyphs.volume, available: () => Audio.stream !== null, run: up => Audio.adjust(Audio.stream, up) },
    streamMute: { icon: () => Glyphs.volumeOff, state: "streamMuted", available: () => Audio.stream !== null, run: () => Audio.toggleMute(Audio.stream) },
    wifi: { icon: () => Network.wifiEnabled ? Glyphs.wifi : Glyphs.disconnected, state: "wifi", available: () => Network.wifiPresent && !Network.wifiBlocked, run: () => Network.toggleWifi() },
    bluetooth: { icon: () => Bluez.enabled ? Glyphs.bluetooth : Glyphs.bluetoothOff, state: "bluetooth", available: () => Bluez.present, run: () => Bluez.toggle() },
    playPause: { icon: () => Glyphs.playPause, available: () => Music.canPlay, run: () => Music.togglePlaying() },
    track: { pair: true, icon: () => Glyphs.track, available: () => Music.canSkip, run: forward => Music.skip(forward) },
    repeat: { icon: () => Glyphs.repeat, state: "repeat", available: () => Music.canRepeat, run: () => Music.toggleRepeat() },
    shuffle: { icon: () => Glyphs.shuffle, state: "shuffle", available: () => Music.canShuffle, run: () => Music.toggleShuffle() },
    keepAwake: { icon: () => Glyphs.keepAwake, state: "keepAwake", available: () => true, run: () => KeepAwake.toggle() },
    powerProfile: { icon: () => Glyphs.powerProfiles[Power.profile] ?? Glyphs.powerProfiles.balanced, detail: () => Power.profile ? Words.powerProfiles[Power.profile].toLowerCase() : "", available: () => Power.profilesPresent, run: () => Power.nextProfile() },
    keyboardLayout: { icon: () => Glyphs.keyboard, available: () => KeyboardLayout.names.length > 1, run: () => KeyboardLayout.next() },
    // Filters the level's list in place; beside it, the nine rows at rest of all it can show, when there are more (1-9 of 14).
    pick: {
      icon: () => Glyphs.search,
      available: list => list.length > 0,
      detail: list => {
        const shown = list.filter(item => !item.hidden).length;
        return shown > 9 ? Words.shownOf(shown) : "";
      },
      run: (second, list, menu) => menu.startFilter()
    }
  })
}
