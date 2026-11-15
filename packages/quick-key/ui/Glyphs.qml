pragma Singleton

import QtQuick
import Quickshell
import qs

// The icon set, named after the Nerd Fonts glyph list; a feature's glyphs setting overrides its defaults.
Singleton {
  readonly property string microphone: Config.audio.glyphs.microphone ?? "\u{F036C}" // md-microphone
  readonly property string microphoneOff: Config.audio.glyphs.microphoneOff ?? "\u{F036D}" // md-microphone_off
  readonly property string music: Config.music.glyphs.music ?? "\u{F075A}" // md-music
  readonly property string shuffle: Config.music.glyphs.shuffle ?? "\u{F049F}" // md-shuffle_variant
  readonly property string repeat: Config.music.glyphs.repeat ?? "\u{F0456}" // md-repeat

  readonly property string wifi: "\u{F05A9}" // md-wifi
  readonly property string ethernet: "\u{F0200}" // md-ethernet
  readonly property string disconnected: "\u{F05AA}" // md-wifi_off
  readonly property string volumeOff: "\u{F075F}" // md-volume_off
  readonly property string keyboard: "\u{F030C}" // md-keyboard
  readonly property string bluetooth: "\u{F00AF}" // md-bluetooth
  readonly property string bluetoothConnected: "\u{F00B1}" // md-bluetooth_connect
  readonly property string bluetoothOff: "\u{F00B2}" // md-bluetooth_off
  readonly property string notifications: "\u{F009A}" // md-bell
  readonly property string doNotDisturb: "\u{F009B}" // md-bell_off
  readonly property string keepAwake: "\u{F0176}" // md-coffee
  readonly property string tray: "\u{F003B}" // md-apps
  readonly property string wallpaper: "\u{F0E09}" // md-wallpaper
  readonly property string window: "\u{F0614}" // md-application_outline
  readonly property string record: "\u{F044B}" // md-record_rec
  readonly property string calendar: "\u{F00ED}" // md-calendar
  readonly property var brightnessLevels: ["\u{F00DE}", "\u{F00DF}", "\u{F00E0}"] // md-brightness_5, _6, _7
  readonly property string check: "\u{F012C}" // md-check
  readonly property string submenu: "\u{F0142}" // md-chevron_right
  readonly property string link: "\u{F0337}" // md-link
  readonly property var audioDevices: ({
    headphones: "\u{F02CB}", // md-headphones
    headset: "\u{F02CE}", // md-headset
    internal: "\u{F0F5F}", // md-monitor_speaker
    external: "\u{F04C3}", // md-speaker
    microphone: "\u{F036C}" // md-microphone
  })
  // md-battery_outline, md-battery_10 to _90, md-battery
  readonly property var batteryLevels: ["\u{F008E}", "\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"]
  // md-battery_charging_outline, md-battery_charging_10 to _100
  readonly property var batteryChargingLevels: ["\u{F089F}", "\u{F089C}", "\u{F0086}", "\u{F0087}", "\u{F0088}", "\u{F089D}", "\u{F0089}", "\u{F089E}", "\u{F008A}", "\u{F008B}", "\u{F0085}"]

  // A device type: headphones, headset, internal, external or microphone.
  function audioDevice(type) {
    return Config.audio.glyphs[type] ?? audioDevices[type] ?? Config.audio.glyphs.external ?? audioDevices.external;
  }

  function brightness(percentage) {
    return brightnessLevels[percentage < 30 ? 0 : percentage < 70 ? 1 : 2];
  }

  // One per 10%.
  function battery(percentage, pluggedIn) {
    const configured = pluggedIn ? Config.battery.glyphs.charging : Config.battery.glyphs.discharging;
    const levels = configured?.length ? configured : pluggedIn ? batteryChargingLevels : batteryLevels;
    return levels[Math.min(10, Math.floor(percentage / 10))] ?? "";
  }
}
