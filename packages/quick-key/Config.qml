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

  // Whether a key is one of a settings object's settings: not a helper it reads (readonly, a function) nor QtObject's own; written back to test, as QML says no other way.
  function settable(object, key) {
    if (!(key in object) || key === "objectName" || typeof object[key] === "function") return false;
    try {
      object[key] = object[key];
      return true;
    } catch (error) {
      return false;
    }
  }

  // Keys renamed, by their old path to their new one: a config still setting an old one fails its check saying what to write instead. A rename adds its line here.
  readonly property var renamed: ({
      "theme.monochromeTray": "theme.appIcons, true as \"grey\""
    })

  // A plugin's setting as given, a map over its default map, as the core's groups take part of theirs.
  function over(declared, value) {
    return kind(declared) === "map" && kind(value) === "map" ? Object.assign({}, declared, value) : value;
  }

  // A plugin's part of config.json over the settings it declares (`declared`, made with their defaults): the values it can take, a map over its default map; and the keys it cannot, undeclared or of another kind. The loader and the check both read it this way.
  function pluginSettings(declared, spec) {
    const [values, unknown, mistyped] = [{}, [], []];
    for (const key of Object.keys(spec).filter(key => key !== "type")) {
      if (!settable(declared, key)) unknown.push(key);
      else if (declared[key] !== null && kind(spec[key]) !== kind(declared[key])) mistyped.push(key);
      else values[key] = over(declared[key], spec[key]);
    }
    return { values, unknown, mistyped };
  }

  // What json sets that the settings do not declare, or declare as another kind of value (`kinds`, as kindsOf reads them); lists and maps are not looked into.
  function undeclared(json, kinds = declaredKinds, path = "") {
    let found = [];
    for (const key of Object.keys(json)) {
      const [value, declared] = [json[key], kinds[key]];
      if (!(key in kinds)) found.push(path + key + " is not a setting");
      else if (typeof declared === "object")
        found = found.concat(kind(value) === "map" ? undeclared(value, declared, path + key + ".") : [path + key + " holds settings, not a value"]);
      else if (declared !== "object" && kind(value) !== declared) found.push(path + key + " takes a " + declared);
    }
    return found;
  }

  // Each setting's kind, by name, a group's as its own table; read from the defaults, as a loaded value would only be compared with itself.
  function kindsOf(group) {
    const kinds = Object.create(null);
    for (const key of Object.keys(group)) {
      const value = group[key];
      if (key === "objectName" || typeof value === "function") continue;
      kinds[key] = value !== null && typeof value === "object" && "objectName" in value ? kindsOf(value) : kind(value);
    }
    return kinds;
  }

  // The settings' kinds, read before config.json loads over their defaults.
  property var declaredKinds: Object.create(null)
  Component.onCompleted: declaredKinds = kindsOf(adapter)

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

  // A theme file missing as the shell started has no change to watch: read again as the menu opens.
  function refresh() {
    if (userTheme.missing) userTheme.reload();
  }
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
        const written = JSON.parse(text());
        if (root.kind(written) !== "map") throw "config.json holds no object of settings";
        root.written = written;
      } catch (error) {
        root.invalid = String(error);
        root.written = {};
      }
    }

    JsonAdapter {
      id: adapter

      property JsonObject theme: JsonObject {
        // A theme by file name: yours in $XDG_CONFIG_HOME/quick-key/themes/, else a preset (catppuccin-mocha, catppuccin-latte, gruvbox-dark, nord, tokyo-night).
        property string name
        // Colours (#rrggbb) over the theme's own.
        property string background
        property string foreground
        property string primary
        property string alert
        property string warning
        // Outlines and dividers; unset, the foreground at disabledOpacity, so tint is left to state.
        property string border
        // Your messages in a conversation, and their text; unset, the foreground at 0.15, and the foreground.
        property string bubble
        property string bubbleText
        // A panel's background opacity, 0 to 1.
        property real surfaceOpacity: 0.92
        // A highlight's opacity (the row under the pointer, a meter's track), 0 to 1.
        property real highlightOpacity: 0.25
        // Secondary text's opacity (values, legends, dim glyphs), 0 to 1: 0.8 keeps it near WCAG AA's 4.5:1 on a dark theme.
        property real dimOpacity: 0.8
        // The opacity a row that cannot run now fades to, 0 to 1.
        property real disabledOpacity: 0.5
        // Milliseconds a fade or colour change takes; 0 for none.
        property int animationDuration: 100
        // The one font, by family: monospace, since sizes are counted in its characters.
        property string monospaceFont: "monospace"
        // The font's size, in points.
        property int fontSize: 11
        // Wrapped prose (an answer) at this multiple of a line; rows keep their own padding.
        property real lineHeight: 1.3
        // Corner radius of panels and cards, in pixels.
        property int radius: 10
        // Corner radius of rows, highlights and tips, in pixels.
        property int itemRadius: 6
        // An icon's size, in pixels.
        property int iconSize: 24
        // Apps' own icons (the tray's, a notification's): "colour" as drawn, "grey" like the glyphs beside them, or "tint", in the text's colour, which keeps a white symbolic icon legible on a light theme.
        property string appIcons: "colour"
        // The menu, pop-ups and cards keep clear of space another bar reserves, instead of covering it.
        property bool besideBars: false
        // Outlines and dividers, in device pixels.
        property int borderWidth: 1
        // The gap between items, in pixels.
        property int spacing: 8
        // The space inside a panel's or a card's edge, in pixels.
        property int padding: 14
        // A row's padding across and down, in pixels.
        property int itemPaddingX: 8
        property int itemPaddingY: 5
        // The gap between a list's rows, in pixels.
        property int listSpacing: 0
        // The distance from the screen's edge to the menu, pop-ups and cards, in pixels.
        property int edgeMargin: 35
        // The pop-up's level bar length and icon size, in pixels.
        property int osdLength: 160
        property int osdIconSize: 28
        // A meter's thickness, and its length in a row, in pixels.
        property int meterThickness: 6
        property int meterLength: 48
      }

      property JsonObject menu: JsonObject {
        // The top level's entries; unset (null), the starter menu in menu.json, which setting entries replaces whole.
        property var entries: null
        // The top level's bar, like waybar's modules-left, -center and -right: entries, and statuses and plugins by name; a slot unset (null) is the starter's.
        property JsonObject header: JsonObject {
          property var left: null
          property var center: null
          property var right: null
        }
        // A level's width in pixels, unless its entry sets `width`.
        property int width: 960
        // The columns a level lays its actions out in, unless its entry sets `columns`.
        property int columns: 2
        // The top level's input, as an entry's `input`: the catch-all line to a plugin or a command.
        property var input: null
        // The screen edge the menu and plugins' panels sit at, its bar against it: bottom or top.
        property string edge: "bottom"
        // Where along that edge: left, center or right.
        property string align: "center"
        // Where a level's input sits: past its body ("body"), or between the body and the bar ("bar"), where a body of another height moves it less.
        property string inputSide: "body"
      }

      property JsonObject clock: JsonObject {
        // The clock status's format: strftime as waybar takes it, plus %o for the English ordinal; unset, the locale's long date and short time.
        property string format
        // The locale every date and time is said in (en_GB): its names, and 24 or 12 hours; unset, the system's (LC_TIME).
        property string locale
        // The calendar's first day of the week, 0 for Sunday to 6 for Saturday; unset (-1), the locale's.
        property int firstDayOfWeek: -1
      }

      property JsonObject calendar: JsonObject {
        // The events file the month shows, by default $XDG_STATE_HOME/quick-key/events.json; until it exists, the month alone.
        property string file: root.stateDir + "/events.json"
        // Given an event's title and when (14:00 · Rua Augusta 120), reminds of it; empty, no reminders.
        property string remind: "notify-send --app-name=Calendar --icon=x-office-calendar"
        // Minutes before a timed event starts that `remind` runs.
        property int remindBefore: 10
        // Minutes after the last sync before it shows in warning.
        property int staleAfter: 120
      }

      property JsonObject popups: JsonObject {
        // Milliseconds a pop-up stays.
        property int timeout: 1500
        // The statuses and plugins whose changes pop up, by name; battery's as it is plugged in or out.
        property var show: ["sink", "source", "brightness", "keyboardLayout", "keepAwake"]
      }

      property JsonObject audio: JsonObject {
        // Percent a volume key or a wheel notch moves the volume.
        property int step: 5
        // The most a volume key or the wheel raises it to, in percent.
        property int max: 100
      }

      property JsonObject bluetooth: JsonObject {
        // Unblocks an adapter rfkill turned off, so the Bluetooth action can power it on.
        property string unblock: "rfkill unblock bluetooth"
      }

      property JsonObject brightness: JsonObject {
        // Prints the path of a file holding the backlight's value, a tab, and its maximum; by default the first backlight.
        property string backlight: 'for d in /sys/class/backlight/*; do [ -r "$d/brightness" ] && printf "%s\\t%s\\n" "$d/brightness" "$(cat "$d/max_brightness")" && break; done'
        // Percent a key or a wheel notch moves the backlight.
        property int step: 5
        // Given the backlight's name and a value, sets it; by default through logind, which lets the active session do so without root.
        property string set: "busctl call org.freedesktop.login1 /org/freedesktop/login1/session/auto org.freedesktop.login1.Session SetBrightness ssu backlight"
        // The output the backlight lights, by connector name or by make, model and serial; unset, the built-in one (eDP, LVDS or DSI).
        property string panel
      }

      property JsonObject keyboardLayout: JsonObject {
        // A short label per layout, in the compositor's order (["US", "PT"]); unset, the first two letters of its name.
        property var labels: []
      }

      property JsonObject daemons: JsonObject {
        // Prints the names on the system bus, running or started on demand, the first on each line: what a built-in that needs a daemon looks for (power profiles).
        property string list: "busctl --system list --no-legend --no-pager"
      }

      property JsonObject battery: JsonObject {
        // Percent of charge at which, on battery, the battery status warns, then alerts, and `warn` runs.
        property int low: 20
        property int critical: 5
        // Given a title and a line (Battery low, 18% left), as the charge falls to low or critical, once each; empty, no warnings.
        property string warn: "notify-send --app-name=Battery --icon=battery-caution"
      }

      property JsonObject music: JsonObject {
        // The MPRIS identity of the player the music status follows; unset, the one playing, else any.
        property string player
      }

      // Optional parts by name, each its settings and `type`: see docs/src/plugins.md.
      property var plugins: ({})

      // Any icon by its name in ui/Glyphs.qml (wifi, audioDevices, batteryLevels), over its default: a glyph, a list of them, or a map.
      property var glyphs: ({})
    }
  }
}
