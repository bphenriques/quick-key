pragma Singleton

import QtQuick
import Quickshell
import qs

// The icon set, named after the Nerd Fonts glyph list; `glyphs` in config.json overrides any by its name here.
Singleton {
  readonly property string microphone: Config.glyphs.microphone ?? "\u{F036C}" // md-microphone
  readonly property string microphoneOff: Config.glyphs.microphoneOff ?? "\u{F036D}" // md-microphone_off
  readonly property string music: Config.glyphs.music ?? "\u{F075A}" // md-music
  readonly property string musicPaused: Config.glyphs.musicPaused ?? "\u{F03E4}" // md-pause
  readonly property string musicOff: Config.glyphs.musicOff ?? "\u{F075B}" // md-music_off
  readonly property string shuffle: Config.glyphs.shuffle ?? "\u{F049F}" // md-shuffle_variant
  readonly property string repeat: Config.glyphs.repeat ?? "\u{F0456}" // md-repeat

  readonly property string wifi: Config.glyphs.wifi ?? "\u{F05A9}" // md-wifi
  readonly property string ethernet: Config.glyphs.ethernet ?? "\u{F0200}" // md-ethernet
  readonly property string disconnected: Config.glyphs.disconnected ?? "\u{F05AA}" // md-wifi_off
  readonly property string volume: Config.glyphs.volume ?? "\u{F057E}" // md-volume_high
  readonly property string volumeOff: Config.glyphs.volumeOff ?? "\u{F075F}" // md-volume_off
  readonly property string keyboard: Config.glyphs.keyboard ?? "\u{F030C}" // md-keyboard
  readonly property string bluetooth: Config.glyphs.bluetooth ?? "\u{F00AF}" // md-bluetooth
  readonly property string bluetoothConnected: Config.glyphs.bluetoothConnected ?? "\u{F00B1}" // md-bluetooth_connect
  readonly property string bluetoothOff: Config.glyphs.bluetoothOff ?? "\u{F00B2}" // md-bluetooth_off
  readonly property string playPause: Config.glyphs.playPause ?? "\u{F040E}" // md-play_pause
  readonly property string track: Config.glyphs.track ?? "\u{F04AD}" // md-skip_next
  readonly property string keepAwake: Config.glyphs.keepAwake ?? "\u{F0176}" // md-coffee
  readonly property string tray: Config.glyphs.tray ?? "\u{F003B}" // md-apps
  readonly property string notifications: Config.glyphs.notifications ?? "\u{F009A}" // md-bell
  readonly property string notificationsPaused: Config.glyphs.notificationsPaused ?? "\u{F009B}" // md-bell_off
  readonly property string close: Config.glyphs.close ?? "\u{F0156}" // md-close
  readonly property string urgent: Config.glyphs.urgent ?? "\u{F0026}" // md-alert
  readonly property string window: Config.glyphs.window ?? "\u{F0614}" // md-application_outline
  readonly property string record: Config.glyphs.record ?? "\u{F044B}" // md-record_rec
  readonly property string calendar: Config.glyphs.calendar ?? "\u{F00ED}" // md-calendar
  readonly property string checkbox: Config.glyphs.checkbox ?? "\u{F0131}" // md-checkbox_blank_outline
  readonly property string checkboxChecked: Config.glyphs.checkboxChecked ?? "\u{F0132}" // md-checkbox_marked
  readonly property string late: Config.glyphs.late ?? "\u{F0020}" // md-alarm
  readonly property var brightnessLevels: Config.glyphs.brightnessLevels ?? ["\u{F00DE}", "\u{F00DF}", "\u{F00E0}"] // md-brightness_5, _6, _7
  readonly property string check: Config.glyphs.check ?? "\u{F012C}" // md-check
  readonly property string search: Config.glyphs.search ?? "\u{F0349}" // md-magnify
  // The tasks' order and what their done ones show, each by its value.
  readonly property var sorts: Object.assign({
    due: "\u{F1547}", // md-sort_calendar_ascending
    priority: "\u{F1389}", // md-sort_numeric_ascending
    title: "\u{F05BD}", // md-sort_alphabetical_ascending
    list: "\u{F1860}" // md-format_list_group
  }, Config.glyphs.sorts ?? {})
  readonly property var completed: Object.assign({
    hidden: "\u{F06D1}", // md-eye_off_outline
    shown: "\u{F06D0}", // md-eye_outline
    only: "\u{F012D}" // md-check_all
  }, Config.glyphs.completed ?? {})
  // A task's priority, as iCalendar groups its ranks.
  readonly property var priorities: Object.assign({
    high: "\u{F013F}", // md-chevron_double_up
    medium: "\u{F01FC}", // md-equal
    low: "\u{F013C}" // md-chevron_double_down
  }, Config.glyphs.priorities ?? {})
  readonly property string submenu: Config.glyphs.submenu ?? "\u{F0142}" // md-chevron_right
  // What marks a prompt: an input with the keys, and what was asked in Ask.
  readonly property string prompt: Config.glyphs.prompt ?? "\u{F0142}" // md-chevron_right
  // A past conversation, as Ask lists them.
  readonly property string conversation: Config.glyphs.conversation ?? "\u{F0EDE}" // md-chat_outline
  readonly property string copy: Config.glyphs.copy ?? "\u{F0C5}" // fa-copy
  readonly property string failed: Config.glyphs.failed ?? "\u{F05D6}" // md-alert_circle_outline
  // A power profile by its name.
  readonly property var powerProfiles: Object.assign({
    "power-saver": "\u{F032A}", // md-leaf
    balanced: "\u{F05D1}", // md-scale_balance
    performance: "\u{F04C5}" // md-speedometer
  }, Config.glyphs.powerProfiles ?? {})
  readonly property var audioDevices: Object.assign({
    headphones: "\u{F02CB}", // md-headphones
    headset: "\u{F02CE}", // md-headset
    internal: "\u{F0F5F}", // md-monitor_speaker
    external: "\u{F04C3}", // md-speaker
    microphone: "\u{F036C}" // md-microphone
  }, Config.glyphs.audioDevices ?? {})
  // md-battery_outline, md-battery_10 to _90, md-battery
  readonly property var batteryLevels: Config.glyphs.batteryLevels ?? ["\u{F008E}", "\u{F007A}", "\u{F007B}", "\u{F007C}", "\u{F007D}", "\u{F007E}", "\u{F007F}", "\u{F0080}", "\u{F0081}", "\u{F0082}", "\u{F0079}"]
  // md-battery_charging_outline, md-battery_charging_10 to _100
  readonly property var batteryChargingLevels: Config.glyphs.batteryChargingLevels ?? ["\u{F089F}", "\u{F089C}", "\u{F0086}", "\u{F0087}", "\u{F0088}", "\u{F089D}", "\u{F0089}", "\u{F089E}", "\u{F008A}", "\u{F008B}", "\u{F0085}"]

  // md-wifi_strength_outline, md-wifi_strength_1 to _4
  readonly property var wifiLevels: Config.glyphs.wifiLevels ?? ["\u{F092F}", "\u{F091F}", "\u{F0922}", "\u{F0925}", "\u{F0928}"]
  // md-wifi_strength_alert_outline, md-wifi_strength_1_alert to _4_alert
  readonly property var wifiLimitedLevels: Config.glyphs.wifiLimitedLevels ?? ["\u{F092B}", "\u{F0920}", "\u{F0923}", "\u{F0926}", "\u{F0929}"]

  // A device type: headphones, headset, internal, external or microphone.
  function audioDevice(type) {
    return audioDevices[type] ?? audioDevices.external;
  }

  function brightness(percentage) {
    return level(brightnessLevels, percentage);
  }

  function battery(percentage, pluggedIn) {
    return level(pluggedIn ? batteryChargingLevels : batteryLevels, percentage);
  }

  function wifiSignal(percentage, limited) {
    return level(limited ? wifiLimitedLevels : wifiLevels, percentage);
  }

  // A list of glyphs over 0 to 100, an even share each, so a theme may give as many as its font has.
  function level(levels, percentage) {
    return levels[Math.min(levels.length - 1, Math.floor(percentage * levels.length / 101))] ?? "";
  }
}
