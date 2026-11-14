pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// Typed view of $XDG_CONFIG_HOME/quickkey/config.json, its schema in modules/home-manager/quickkey/settings.nix.
// Grouped by feature, like waybar's modules; every setting is optional, and commands are run with sh -c.
Singleton {
  id: root

  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quickkey"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quickkey"

  // A colour set in theme wins over theme.name's file (the user's, then the shipped preset), which wins over the default.
  readonly property QtObject colors: QtObject {
    readonly property color background: adapter.theme.background || userTheme.palette.background || shippedTheme.palette.background || "#1d1f21"
    readonly property color foreground: adapter.theme.foreground || userTheme.palette.foreground || shippedTheme.palette.foreground || "#c5c8c6"
    readonly property color primary: adapter.theme.primary || userTheme.palette.primary || shippedTheme.palette.primary || "#81a2be"
    readonly property color alert: adapter.theme.alert || userTheme.palette.alert || shippedTheme.palette.alert || "#cc6666"
    readonly property color warning: adapter.theme.warning || userTheme.palette.warning || shippedTheme.palette.warning || "#f0c674"
  }

  readonly property alias theme: adapter.theme
  readonly property alias menu: adapter.menu
  readonly property alias clock: adapter.clock
  readonly property alias calendar: adapter.calendar
  readonly property alias popups: adapter.popups
  readonly property alias audio: adapter.audio
  readonly property alias brightness: adapter.brightness
  readonly property alias keepAwake: adapter.keepAwake
  readonly property alias keyboardLayout: adapter.keyboardLayout
  readonly property alias battery: adapter.battery
  readonly property alias music: adapter.music
  readonly property alias plugins: adapter.plugins

  // Keys of json that object does not declare, by path; free-form values (lists, maps) are not looked into.
  function unknownKeys(json, object, path) {
    let found = [];
    for (const key of Object.keys(json)) {
      const value = object[key];
      if (!(key in object)) found.push(path + key);
      else if (value !== null && typeof value === "object" && "objectName" in value && json[key] !== null && typeof json[key] === "object")
        found = found.concat(unknownKeys(json[key], value, path + key + "."));
    }
    return found;
  }

  ThemeFile {
    id: userTheme
    path: adapter.theme.name ? root.configDir + "/themes/" + adapter.theme.name + ".json" : ""
  }

  ThemeFile {
    id: shippedTheme
    path: adapter.theme.name ? Quickshell.shellDir + "/themes/" + adapter.theme.name + ".json" : ""
  }

  // The starter menu, shaped as a config.json to copy from. Not a default bound in the adapter: it writes without breaking
  // bindings, so this file loading after config.json would replace the user's entries.
  readonly property var starterEntries: starter.entries

  FileView {
    path: Quickshell.shellDir + "/menu.json"

    JsonAdapter {
      property JsonObject menu: JsonObject {
        id: starter
        property var entries: []
      }
    }
  }

  readonly property bool themeMissing: userTheme.missing && shippedTheme.missing
  onThemeMissingChanged: if (themeMissing) console.warn("theme", adapter.theme.name, "not found in", configDir + "/themes or the presets");

  // A reload rather than a re-read, so removed settings fall back to their defaults.
  FileView {
    path: root.configDir + "/config.json"
    watchChanges: true
    printErrors: false
    onFileChanged: Quickshell.reload(false)

    // A misspelt setting would otherwise do nothing, silently.
    onLoaded: {
      try {
        const unknown = root.unknownKeys(JSON.parse(text()), adapter, "");
        if (unknown.length) console.warn("config.json: ignoring unknown settings:", unknown.join(", "));
      } catch (error) {
        console.warn("config.json:", error);
      }
    }

    JsonAdapter {
      id: adapter

      property JsonObject theme: JsonObject {
        // A theme in $XDG_CONFIG_HOME/quickkey/themes/ or a shipped one (themes/), by file name.
        property string name
        // Override the theme's colours, read through Config.colors.
        property string background
        property string foreground
        property string primary
        property string alert
        property string warning
        property real surfaceOpacity: 0.92
        property real highlightOpacity: 0.25
        property real dimOpacity: 0.5
        // Milliseconds a fade or colour change takes; 0 for none.
        property int animationDuration: 100
        property string monospaceFont: "monospace"
        property int fontSize: 11
        property int radius: 10
        property int itemRadius: 6
        property int iconSize: 24
        property int borderWidth: 2
        property int spacing: 8
        property int padding: 14
        property int itemPaddingX: 8
        property int itemPaddingY: 5
        property int listSpacing: 0
        property int edgeMargin: 35
        property int osdLength: 160
        property int osdIconSize: 28
        property int meterThickness: 6
        property int meterLength: 48
      }

      property JsonObject menu: JsonObject {
        // Unset (null), the starter menu in menu.json (Config.starterEntries); setting entries replaces it whole.
        property var entries: null
        // The top level's header, like waybar's modules-left, -center and -right: built-in items and plugins, by name (docs/src/menu.md).
        property JsonObject header: JsonObject {
          property var left: ["clock"]
          property var center: []
          property var right: ["keepAwake", "keyboardLayout", "battery"]
        }
        property int width: 960
        property int columns: 2
      }

      property JsonObject clock: JsonObject {
        // strftime, as waybar's clock takes it (see services/Clock.qml); unset, the locale's long date and short time.
        property string format
        // The locale the clock and calendar name days and months in (en_GB); unset, the system's for dates (LC_TIME).
        property string locale
        // The calendar's, 0 for Sunday to 6 for Saturday; unset (-1), the locale's.
        property int firstDayOfWeek: -1
      }

      property JsonObject calendar: JsonObject {
        // The events file the month shows (docs/src/calendar.md); not there yet, the month alone.
        property string file: root.stateDir + "/events.json"
        // Given an event's title and when (14:00 · Rua Augusta 120), reminds of it; empty, no reminders.
        property string remind: "notify-send --app-name=Calendar --icon=x-office-calendar"
        // How many minutes before a timed event starts.
        property int remindBefore: 10
      }

      property JsonObject popups: JsonObject {
        // How long a pop-up stays, in milliseconds.
        property int timeout: 1500
        // Which changes pop up.
        property var show: ["sink", "source", "brightness", "keyboardLayout", "keepAwake"]
      }

      property JsonObject audio: JsonObject {
        // Prints one device per line: kind (sink or source), name, type and friendly name, tab separated, internal first.
        property string devices
        // Given a kind and a device name, makes it the default.
        property string select
        // The pop-up wheel's commands, down then up, for the sink and the source.
        property var adjust: ({
          sink: ["wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SINK@ 5%+"],
          source: ["wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 5%-", "wpctl set-volume -l 1 @DEFAULT_AUDIO_SOURCE@ 5%+"]
        })
        // By device type (headphones, headset, internal, external, microphone), and microphoneOff.
        property var glyphs: ({})
      }

      property JsonObject brightness: JsonObject {
        // Prints the path of a file holding the backlight's value, a tab, and its maximum; by default the first backlight.
        property string backlight: 'for d in /sys/class/backlight/*; do [ -r "$d/brightness" ] && printf "%s\\t%s\\n" "$d/brightness" "$(cat "$d/max_brightness")" && break; done'
        // The pop-up wheel's commands, down then up.
        property var adjust: ["brightnessctl set 5%-", "brightnessctl set 5%+"]
        // The panel the backlight dims; unset, the built-in output (eDP, LVDS or DSI).
        property string panel
      }

      property JsonObject keepAwake: JsonObject {
        // Inhibits idle until its stdin closes; exec, so stopping it releases the lock.
        property string command: 'exec systemd-inhibit --what=idle --who=quickkey --why="Keep awake" cat'
        property string shortcut
      }

      property JsonObject keyboardLayout: JsonObject {
        // A short label per layout, in the compositor's order; unset, the first letters of its name.
        property var labels: []
        property string shortcut
      }

      property JsonObject battery: JsonObject {
        property int low: 20
        property int critical: 5
        // One per 10%, empty to full.
        property var glyphs: ({ discharging: [], charging: [] })
      }

      property JsonObject music: JsonObject {
        // The MPRIS identity of the player the Music status follows; unset, the one playing, else any.
        property string player
        // music, shuffle and repeat.
        property var glyphs: ({})
      }

      // Optional parts by name, each { source, settings }: see docs/src/plugins.md.
      property var plugins: ({})
    }
  }
}
