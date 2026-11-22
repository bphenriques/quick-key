pragma Singleton
pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io

// The schema of $XDG_CONFIG_HOME/quick-key/config.json: each key, its kind and its default; Validation.qml holds what else can be wrong.
Singleton {
  id: root

  readonly property string configDir: (Quickshell.env("XDG_CONFIG_HOME") || Quickshell.env("HOME") + "/.config") + "/quick-key"
  readonly property string stateDir: (Quickshell.env("XDG_STATE_HOME") || Quickshell.env("HOME") + "/.local/state") + "/quick-key"

  // A colour set in theme wins over theme.name's file (the user's, then the shipped preset), which wins over `fallback`.
  function colorOf(name, fallback) {
    return adapter.theme[name] || userTheme.palette[name] || shippedTheme.palette[name] || fallback;
  }

  readonly property QtObject colors: QtObject {
    readonly property color background: root.colorOf("background", "#1d1f21")
    readonly property color foreground: root.colorOf("foreground", "#c5c8c6")
    readonly property color primary: root.colorOf("primary", "#61afef")
    readonly property color alert: root.colorOf("alert", "#cc6666")
    readonly property color warning: root.colorOf("warning", "#f0c674")
    readonly property color border: root.colorOf("border", Qt.alpha(foreground, adapter.theme.disabledOpacity))
    // Your messages in a conversation; unset, the foreground at 0.15, which keeps its text near WCAG AA's 4.5:1.
    readonly property color bubble: root.colorOf("bubble", Qt.alpha(foreground, 0.15))
    readonly property color bubbleText: root.colorOf("bubbleText", foreground)
  }

  readonly property alias theme: adapter.theme
  readonly property alias menu: adapter.menu
  readonly property alias clock: adapter.clock
  readonly property alias calendar: adapter.calendar
  readonly property alias popups: adapter.popups
  readonly property alias audio: adapter.audio
  readonly property alias bluetooth: adapter.bluetooth
  readonly property alias brightness: adapter.brightness
  readonly property alias keyboardLayout: adapter.keyboardLayout
  readonly property alias battery: adapter.battery
  readonly property alias daemons: adapter.daemons
  readonly property alias music: adapter.music
  readonly property alias plugins: adapter.plugins
  readonly property alias glyphs: adapter.glyphs

  // config.json as written: {} without one, null until read, and why it could not be parsed.
  property var written: null
  property string invalid: ""

  // A value's kind as the checks name it: a list, a map, else its type; a list read back from the adapter is list-like, not an Array.
  function kind(value) {
    if (value === null || typeof value !== "object") return typeof value;
    return Array.isArray(value) || typeof value.length === "number" ? "list" : "map";
  }

  // What json sets that the settings do not declare, or declare as another kind of value; lists and maps are not looked into.
  function undeclared(json, group = adapter, path = "") {
    let found = [];
    for (const key of Object.keys(json)) {
      const [value, declared] = [json[key], group[key]];
      if (!(key in group)) found.push(path + key + " is not a setting");
      else if (declared !== null && typeof declared === "object" && "objectName" in declared)
        found = found.concat(kind(value) === "map" ? undeclared(value, declared, path + key + ".") : [path + key + " holds settings, not a value"]);
      else if (declared !== null && kind(value) !== kind(declared)) found.push(path + key + " takes a " + kind(declared));
    }
    return found;
  }

  // A plugin's file as candidate URLs: a type with a slash is its path, else its name in the user's plugins, then the shipped ones.
  function pluginUrls(name, spec) {
    const type = spec.type ?? name;
    const file = type + "/" + type.charAt(0).toUpperCase() + type.slice(1) + ".qml";
    const paths = type.includes("/") ? [type] : [root.configDir + "/plugins/" + file, "plugins/" + file];
    return paths.map(path => path.startsWith("/") ? "file://" + path : Quickshell.shellPath(path));
  }

  ThemeFile {
    id: userTheme
    path: adapter.theme.name ? root.configDir + "/themes/" + adapter.theme.name + ".json" : ""
  }

  ThemeFile {
    id: shippedTheme
    path: adapter.theme.name ? Quickshell.shellDir + "/themes/" + adapter.theme.name + ".json" : ""
  }

  // Not bound as the adapter's defaults: menu.json loading after config.json would then replace the user's entries.
  readonly property var starterEntries: starter.entries
  readonly property var starterHeader: starter.header

  // A slot of the top level's bar: as set, else the starter's.
  function headerSlot(slot) {
    return adapter.menu.header[slot] ?? starter.header[slot] ?? [];
  }

  FileView {
    path: Quickshell.shellDir + "/menu.json"

    JsonAdapter {
      property JsonObject menu: JsonObject {
        id: starter
        property var entries: []
        property JsonObject header: JsonObject {
          property var left: []
          property var center: []
          property var right: []
        }
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

    onLoadFailed: root.written = {}
    onLoaded: {
      try {
        root.written = JSON.parse(text());
      } catch (error) {
        root.invalid = String(error);
        root.written = {};
      }
    }

    JsonAdapter {
      id: adapter

      property JsonObject theme: JsonObject {
        // A theme in $XDG_CONFIG_HOME/quick-key/themes/ or a shipped one (themes/), by file name.
        property string name
        // Override the theme's colours, read through Config.colors.
        property string background
        property string foreground
        property string primary
        property string alert
        property string warning
        // Outlines and dividers; unset, the foreground at disabledOpacity, so tint is left to state.
        property string border
        // Your messages in a conversation, and their text.
        property string bubble
        property string bubbleText
        property real surfaceOpacity: 0.92
        property real highlightOpacity: 0.25
        // Secondary text (values, legend words, dim glyphs) over the panel: 0.8 keeps it near WCAG AA's 4.5:1 on a dark theme.
        property real dimOpacity: 0.8
        // A row that cannot run now, faded whole, and the default outline.
        property real disabledOpacity: 0.5
        // Milliseconds a fade or colour change takes; 0 for none.
        property int animationDuration: 100
        property string monospaceFont: "monospace"
        property int fontSize: 11
        // Wrapped prose (an answer) at this multiple of a line; rows keep their own padding.
        property real lineHeight: 1.3
        property int radius: 10
        property int itemRadius: 6
        property int iconSize: 24
        // Tray icons in a bar in greys, like the glyphs beside them.
        property bool monochromeTray: false
        // Outlines and dividers, in device pixels.
        property int borderWidth: 1
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
        // The top level's bar, like waybar's modules-left, -center and -right: entries, and statuses and plugins by name (docs/src/menu.md); a slot unset (null) is the starter's.
        property JsonObject header: JsonObject {
          property var left: null
          property var center: null
          property var right: null
        }
        property int width: 960
        property int columns: 2
        // The top level's input, as an entry's `input`: the catch-all line to a plugin or a command.
        property var input: null
      }

      property JsonObject clock: JsonObject {
        // strftime, as waybar's clock takes it (see services/Clock.qml); unset, the locale's long date and short time.
        property string format
        // The locale every date and time is said in (en_GB): names, the time's 24 or 12 hours; unset, the system's (LC_TIME).
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
        // Minutes after which the last sync shows in warning.
        property int staleAfter: 120
      }

      property JsonObject popups: JsonObject {
        // How long a pop-up stays, in milliseconds.
        property int timeout: 1500
        // Which changes pop up.
        property var show: ["sink", "source", "brightness", "keyboardLayout", "keepAwake"]
      }

      property JsonObject audio: JsonObject {
        // Percent a volume key or the wheel moves the volume, and the most it reaches.
        property int step: 5
        property int max: 100
      }

      property JsonObject bluetooth: JsonObject {
        // Unblocks an adapter rfkill turned off, so the Bluetooth action can power it on.
        property string unblock: "rfkill unblock bluetooth"
      }

      property JsonObject brightness: JsonObject {
        // Prints the path of a file holding the backlight's value, a tab, and its maximum; by default the first backlight.
        property string backlight: 'for d in /sys/class/backlight/*; do [ -r "$d/brightness" ] && printf "%s\\t%s\\n" "$d/brightness" "$(cat "$d/max_brightness")" && break; done'
        // Percent a key or the wheel moves the backlight.
        property int step: 5
        // Given the backlight's name and a value, sets it; logind lets the active session do so without root.
        property string set: "busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight"
        // The panel the backlight dims; unset, the built-in output (eDP, LVDS or DSI).
        property string panel
      }

      property JsonObject keyboardLayout: JsonObject {
        // A short label per layout, in the compositor's order; unset, the first letters of its name.
        property var labels: []
      }

      property JsonObject daemons: JsonObject {
        // Prints the names on the system bus, running or started on demand, the first on each line: what a built-in that needs a daemon looks for (power profiles).
        property string list: "busctl --system list --no-legend --no-pager"
      }

      property JsonObject battery: JsonObject {
        property int low: 20
        property int critical: 5
      }

      property JsonObject music: JsonObject {
        // The MPRIS identity of the player the Music status follows; unset, the one playing, else any.
        property string player
      }

      // Optional parts by name, each its settings and `type`: see docs/src/plugins.md.
      property var plugins: ({})

      // Any icon by its name in ui/Glyphs.qml (wifi, audioDevices, batteryLevels), over its default.
      property var glyphs: ({})
    }
  }
}
