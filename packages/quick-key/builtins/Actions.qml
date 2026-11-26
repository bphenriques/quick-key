pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// Built-in actions by name, run in place of an entry's `cmd`; no prototype, as in Statuses.qml.
Singleton {
  // Each: run(second, list, menu), told whether a pair's second key was pressed, given its level's list and the menu; detail(list), a value beside it; available(list); icon(), showing its state where it has one; the state lighting it; pair; closes, to hide the menu first.
  readonly property var builtin: Object.assign(Object.create(null), {
    // Turns the default output down, then up, by audio.step.
    sinkVolume: { pair: true, icon: () => Glyphs.volume, available: () => Audio.sink !== null, run: up => Audio.adjust(Audio.sink, up) },
    // Mutes or unmutes the default output.
    sinkMute: { icon: () => Glyphs.volumeOff, state: "sinkMuted", available: () => Audio.sink !== null, run: () => Audio.toggleMute(Audio.sink) },
    // Turns the microphone down, then up, by audio.step.
    sourceVolume: { pair: true, icon: () => Glyphs.microphone, available: () => Audio.source !== null, run: up => Audio.adjust(Audio.source, up) },
    // Dims, then brightens, the backlight by brightness.step.
    brightness: { pair: true, icon: () => Glyphs.brightnessLevels[1], available: () => Brightness.lit, run: up => Brightness.adjust(up) },
    // Mutes or unmutes the microphone.
    sourceMute: { icon: () => Glyphs.microphoneOff, state: "sourceMuted", available: () => Audio.source !== null, run: () => Audio.toggleMute(Audio.source) },
    // Turns the app picked on the streams list down, then up, by audio.step.
    streamVolume: { pair: true, icon: () => Glyphs.volume, available: () => Audio.stream !== null, run: up => Audio.adjust(Audio.stream, up) },
    // Mutes or unmutes the app picked on the streams list.
    streamMute: { icon: () => Glyphs.volumeOff, state: "streamMuted", available: () => Audio.stream !== null, run: () => Audio.toggleMute(Audio.stream) },
    // Turns Wi-Fi on or off.
    wifi: { icon: () => Network.wifiEnabled ? Glyphs.wifi : Glyphs.disconnected, state: "wifi", available: () => Network.wifiPresent && !Network.wifiBlocked, run: () => Network.toggleWifi() },
    // Turns Bluetooth on or off.
    bluetooth: { icon: () => Bluez.enabled ? Glyphs.bluetooth : Glyphs.bluetoothOff, state: "bluetooth", available: () => Bluez.present, run: () => Bluez.toggle() },
    // Plays or pauses the player the music status shows.
    playPause: { icon: () => Glyphs.playPause, available: () => Music.canPlay, run: () => Music.togglePlaying() },
    // The previous track, then the next.
    track: { pair: true, icon: () => Glyphs.track, available: () => Music.canSkip, run: forward => Music.skip(forward) },
    // Turns the player's repeat on or off.
    repeat: { icon: () => Glyphs.repeat, state: "repeat", available: () => Music.canRepeat, run: () => Music.toggleRepeat() },
    // Turns the player's shuffle on or off.
    shuffle: { icon: () => Glyphs.shuffle, state: "shuffle", available: () => Music.canShuffle, run: () => Music.toggleShuffle() },
    // Keeps the screen awake, or lets it sleep again.
    keepAwake: { icon: () => Glyphs.keepAwake, state: "keepAwake", available: () => true, run: () => KeepAwake.toggle() },
    // Steps to the next power profile, the one in use beside it.
    powerProfile: {
      icon: () => Glyphs.powerProfiles[Power.profile] ?? Glyphs.powerProfiles.balanced,
      detail: () => Power.profile ? Words.powerProfiles[Power.profile].toLowerCase() : "",
      available: () => Power.profilesPresent,
      run: () => Power.nextProfile()
    },
    // Switches to the next keyboard layout; with one, it dims.
    keyboardLayout: { icon: () => KeyboardLayout.names.length > 1 ? Glyphs.keyboard : "", available: () => KeyboardLayout.names.length > 1, run: () => KeyboardLayout.next() }
  })
}
