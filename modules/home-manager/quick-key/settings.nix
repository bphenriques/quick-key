# The schema of config.json, the shell's only input: each option is one of its keys, unset ones left out.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.programs.quick-key;
  inherit (cfg) settings;
  jsonType = (pkgs.formats.json { }).type;

  names = import ./builtins.nix;
  builtinStatuses = names.statuses;
  builtinLists = names.lists;
  builtinStates = names.states;
  inherit (names) headerItems;
  popupNames = [
    "sink"
    "source"
    "brightness"
    "keyboardLayout"
    "keepAwake"
  ];
  # Plugins may not take a built-in name.
  builtinNames = builtinStatuses ++ builtinStates ++ builtinLists ++ headerItems;
  pluginNames = lib.attrNames settings.plugins;
  sources = [
    "watch"
    "read"
    "file"
  ];
  manySources = lib.attrNames (
    lib.filterAttrs (_: p: lib.count (source: p.settings.${source} != null) sources > 1) settings.plugins
  );
  everyWithoutRead = lib.attrNames (
    lib.filterAttrs (_: p: p.settings.every != null && p.settings.read == null) settings.plugins
  );
  headerNames = lib.concatLists (lib.filter (slot: slot != null) (lib.attrValues settings.menu.header));

  # Unset, the shell's default applies.
  opt =
    type: description:
    mkOption {
      type = types.nullOr type;
      default = null;
      inherit description;
    };
  group =
    description: options:
    mkOption {
      type = types.submodule { inherit options; };
      default = { };
      inherit description;
    };
  shortcut = opt types.str "Compositor key, shown in the header while Super is held";
  glyphs = opt (types.attrsOf types.str);
  pixels = names: lib.genAttrs names (_: opt types.ints.unsigned "In pixels");

  entry = types.submodule {
    options = {
      key = mkOption {
        type = types.either types.str (types.listOf types.str);
        description = "Key or keys that trigger the entry, as xkb key names, Ctrl+ or Alt+ allowed before them (e.g. `a`, `A`, `Left`, `space`, `Ctrl+Left`)";
      };
      desc = mkOption {
        type = types.str;
        description = "Label shown next to the key";
      };
      cmd = mkOption {
        type = types.nullOr (types.either types.str (types.listOf types.str));
        default = null;
        description = "Command to run, or one per key for a pair (e.g. Down and Up) shown as one row";
      };
      action = mkOption {
        type = types.nullOr (types.enum names.actions);
        default = null;
        description = "Built-in action to run in place of cmd, bringing its icon, lit state and availability: one of ${toString names.actions}";
      };
      keepOpen = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Keep the menu open after running cmd; false closes it after an action, which keeps it open by default";
      };
      activeWhen = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "State that lights the entry while on, for a toggle: one of ${toString builtinStates}, or a plugin's name";
      };
      width = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Width of this entry's level; menu.width otherwise";
      };
      columns = mkOption {
        type = types.nullOr types.ints.positive;
        default = null;
        description = "Columns of this entry's level, entries flowing across; menu.columns otherwise";
      };
      submenu = mkOption {
        type = types.nullOr (types.listOf entry);
        default = null;
        description = "Nested entries";
        # The type nests itself, so the docs list its options once, at the top level.
        visible = "shallow";
      };
      list = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Items filled at runtime, numbered after any submenu: one of ${toString builtinLists} (tray apps, paired Bluetooth devices, saved Wi-Fi networks in range, audio outputs or inputs), or a plugin's name";
      };
      pins = mkOption {
        type = types.nullOr (
          types.listOf (
            types.submodule {
              options = {
                match = mkOption {
                  type = types.str;
                  description = "Pattern, with * for anything, on the item's id: audio node name, Bluetooth address, Wi-Fi name or tray app id";
                };
                label = mkOption {
                  type = types.str;
                  description = "Name shown for the item, also while it is absent";
                };
                icon = mkOption {
                  type = types.nullOr types.str;
                  default = null;
                  description = "Glyph shown for the item, the same present or absent";
                };
              };
            }
          )
        );
        default = null;
        description = "Items of the list that keep digits 1 onwards, dimmed while absent";
      };
      view = mkOption {
        type = types.nullOr (types.enum [ "calendar" ]);
        default = null;
        description = "What the entry's level shows under its entries: a month and its events";
      };
      status = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Status shown in place of the label: one of ${toString builtinStatuses}, or a plugin's name";
      };
      requires = opt (types.submodule {
        options = {
          connected = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Outputs that must be connected for the entry to be enabled: connector name, or make, model and serial";
          };
          enabled = mkOption {
            type = types.listOf types.str;
            default = [ ];
            description = "Outputs that must also be on, e.g. the panel a brightness entry dims";
          };
        };
      }) "Outputs the entry needs; unset, none";
      icon = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Glyph shown before the label: on every action in a level, and on a top-level entry without status";
      };
    };
  };

  # Esc closes the menu and Backspace goes back a level.
  reservedKeys = [
    "Escape"
    "BackSpace"
  ];

  digits = map toString (lib.range 0 9);

  keysOf = entries: lib.concatMap (e: lib.toList e.key) entries;

  levelAssertions =
    path: entries:
    let
      keys = keysOf entries;
      duplicates = lib.unique (lib.filter (k: lib.count (x: x == k) keys > 1) keys);
      # Ctrl and Alt may prefix a key (Ctrl+Left); Shift is the capital letter, Super the compositor's.
      badModifiers = lib.filter (k: k != "+" && builtins.match "((Ctrl|Alt)\\+)*[^+]+" k == null) keys;
      appMenuKeys = lib.filter (k: builtins.match "(Alt\\+)?Ctrl\\+(Alt\\+)?[0-9]" k != null) keys;
      reserved = lib.intersectLists reservedKeys keys;
    in
    [
      {
        assertion = duplicates == [ ];
        message = "programs.quick-key.settings.menu: duplicate keys in ${path}: ${toString duplicates}";
      }
      {
        assertion = badModifiers == [ ];
        message = "programs.quick-key.settings.menu: only Ctrl+ and Alt+ may prefix a key in ${path}: ${toString badModifiers}";
      }
      {
        assertion = appMenuKeys == [ ];
        message = "programs.quick-key.settings.menu: Ctrl+digit opens a listed item's own menu, so ${toString appMenuKeys} in ${path} cannot be bound";
      }
      {
        assertion = reserved == [ ];
        message = "programs.quick-key.settings.menu: ${toString reserved} in ${path} are reserved for the menu";
      }
    ]
    ++ lib.concatMap (e: [
      {
        assertion =
          lib.count (x: x) [
            (e.cmd != null)
            (e.action != null)
            (e.submenu != null || e.list != null || e.view != null)
          ] == 1;
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} needs one of cmd, action, or submenu and/or list or view";
      }
      {
        assertion = e.status == null || lib.elem e.status (builtinStatuses ++ pluginNames);
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} shows status '${toString e.status}', neither built in nor a plugin's";
      }
      {
        assertion = e.activeWhen == null || lib.elem e.activeWhen (builtinStates ++ pluginNames);
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} is lit by '${toString e.activeWhen}', neither built in nor a plugin's";
      }
      {
        assertion = e.list == null || lib.elem e.list (builtinLists ++ pluginNames);
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} lists '${toString e.list}', neither built in nor a plugin's";
      }
      {
        assertion = e.view == null || e.list == null;
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} cannot combine view with list";
      }
      {
        assertion = e.keepOpen == null || e.cmd != null || e.action != null;
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} can only set keepOpen with cmd or action";
      }
      {
        assertion = e.submenu == null || lib.all (a: a.icon != null || a.action != null) e.submenu;
        message = "programs.quick-key.settings.menu: every action in '${e.desc}' needs an icon";
      }
      {
        assertion = e.pins == null || e.list != null;
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} can only set pins with list";
      }
      {
        assertion = e.pins == null || lib.length e.pins <= 9;
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} has more pins than digits";
      }
      {
        assertion = e.list == null || lib.intersectLists digits (keysOf (if e.submenu != null then e.submenu else [ ])) == [ ];
        message = "programs.quick-key.settings.menu: digits in '${e.desc}' are reserved for its list";
      }
      {
        assertion = !(lib.isList e.cmd) || (lib.isList e.key && lib.length e.cmd == lib.length e.key);
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} pairs keys and commands, so needs as many of each";
      }
      {
        assertion = !(lib.elem e.action names.pairs) || (lib.isList e.key && lib.length e.key == 2);
        message = "programs.quick-key.settings.menu: '${e.desc}' in ${path} runs '${toString e.action}' per key of a pair, so needs two keys";
      }
    ]) entries
    ++ lib.concatMap (e: lib.optionals (e.submenu != null) (levelAssertions "${path} > ${e.desc}" e.submenu)) entries;
in
{
  options.programs.quick-key.settings = {
    theme = group "Colours, font and sizes" (
      {
        name = opt types.str "Colour theme: a file in `themes` or a shipped preset (catppuccin-mocha, catppuccin-latte, gruvbox-dark, nord, tokyo-night)";
        background = opt types.str "Background colour, over the theme's";
        foreground = opt types.str "Text colour, over the theme's";
        primary = opt types.str "Colour of what is on or in use, over the theme's";
        alert = opt types.str "Colour of what needs attention, over the theme's";
        warning = opt types.str "Colour of what may soon need attention, over the theme's";
        surfaceOpacity = opt (types.numbers.between 0 1) "Opacity of a panel's background";
        highlightOpacity = opt (types.numbers.between 0 1) "Opacity of a highlight";
        dimOpacity = opt (types.numbers.between 0 1) "Opacity of dimmed text and icons";
        animationDuration = opt types.ints.unsigned "Milliseconds a fade or colour change takes; 0 for none";
        monospaceFont = opt types.str "Font family";
        fontSize = opt types.ints.positive "Font size, in points";
      }
      // pixels [
        "radius"
        "itemRadius"
        "iconSize"
        "borderWidth"
        "spacing"
        "padding"
        "itemPaddingX"
        "itemPaddingY"
        "listSpacing"
        "edgeMargin"
        "osdLength"
        "osdIconSize"
        "meterThickness"
        "meterLength"
      ]
    );

    menu = group "The menu" {
      entries = opt (types.listOf entry) "Top-level entries, ordered with `lib.mkOrder`; unset, a starter menu";
      header = lib.genAttrs [ "left" "center" "right" ] (
        slot:
        opt (types.listOf types.str) "Items in the header's ${slot} third, like waybar's modules-${slot}: ${toString headerItems} or plugins"
      );
      width = opt types.ints.positive "Width of a level, in pixels, unless its entry sets one";
      columns = opt types.ints.positive "Columns of a level, unless its entry sets them";
    };

    clock = group "The header's clock and the calendar's names" {
      format = opt types.str "strftime format, as waybar's clock takes it, `%o` the English ordinal; unset, the locale's long date";
      locale = opt types.str "Locale naming days and months (`en_GB`); unset, the system's";
      firstDayOfWeek = opt (types.ints.between 0 6) "First day of the calendar's week, 0 for Sunday; unset, the locale's";
    };

    calendar = group "The calendar's events" {
      file = opt types.str "Events file the month shows; unset, `$XDG_STATE_HOME/quick-key/events.json`, where `calendarSync` writes";
      remind = opt types.str "Command given an event's title and when, run before each timed event; unset, notify-send, empty for none";
      remindBefore = opt types.ints.unsigned "Minutes before a timed event the reminder runs";
    };

    popups = group "The pop-ups for volume, brightness, layout and keep-awake" {
      timeout = opt types.ints.positive "Milliseconds a pop-up stays";
      show = opt (types.listOf (types.enum popupNames)) "Changes that pop up: ${toString popupNames}; unset, all";
    };

    audio = group "Audio devices" {
      step = opt (types.ints.between 1 100) "Percent a volume key or the wheel moves the volume";
      max = opt (types.ints.between 1 150) "Percent the volume reaches at most";
      glyphs = glyphs "Glyph by device type (headphones, headset, internal, external, microphone) and microphoneOff, over the shipped ones";
    };

    bluetooth = group "The Bluetooth adapter" {
      unblock = opt types.str "Command unblocking an adapter rfkill turned off, so the bluetooth action can power it on; unset, rfkill";
    };

    brightness = group "The backlight" {
      backlight = opt types.str "Command printing the backlight's value file, a tab, and its maximum; unset, the first in /sys/class/backlight";
      adjust = opt (types.listOf types.str) "Commands the wheel runs, down then up; unset, brightnessctl";
      panel = opt types.str "Panel the backlight dims: connector name, or make, model and serial; unset, the eDP, LVDS or DSI output";
    };

    keepAwake = group "Idle inhibition" {
      command = opt types.str "Command inhibiting idle until its stdin closes; unset, systemd-inhibit";
      inherit shortcut;
    };

    keyboardLayout = group "Keyboard layouts" {
      labels = opt (types.listOf types.str) "Short label per layout, in the compositor's order; unset, the first letters of its name";
      inherit shortcut;
    };

    battery = group "The battery" {
      low = opt (types.ints.between 0 100) "Percentage at which the battery shows as low";
      critical = opt (types.ints.between 0 100) "Percentage at which the battery shows as critical";
      glyphs = opt (types.submodule {
        options = lib.genAttrs [ "discharging" "charging" ] (
          _:
          mkOption {
            type = types.listOf types.str;
            description = "Eleven glyphs, empty to full";
          }
        );
      }) "Battery glyphs, over the shipped ones";
    };

    music = group "The music status" {
      player = opt types.str "MPRIS identity of the player to follow; unset, the one playing";
      glyphs = glyphs "Glyph for music, shuffle and repeat";
    };

    plugins = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            source = mkOption {
              type = types.nullOr (types.either types.path types.str);
              default = null;
              description = "The plugin implementing this one, by name (`command`), or a QML file path; unset, its own name";
            };
            settings = mkOption {
              type = types.submodule {
                freeformType = jsonType;
                options = {
                  watch = opt types.str "Command whose every line is the state, run for as long as it lasts";
                  read = opt types.str "Command whose last line is the state, run as the menu opens";
                  file = opt types.str "File holding the state, read on every change; relative, under `$XDG_RUNTIME_DIR`";
                  every = opt types.ints.positive "Seconds between runs of `read` while the menu is open";
                  show = opt (types.attrsOf (
                    types.submodule {
                      freeformType = jsonType;
                      options = {
                        glyph = opt types.str "Glyph shown";
                        text = opt types.str "Text shown";
                        detail = opt types.str "Data on the right";
                        active = opt types.bool "Whether it is lit";
                        tone = opt (types.enum [
                          "primary"
                          "warning"
                          "alert"
                          "dim"
                        ]) "Tone over the one `active` gives";
                      };
                    }
                  )) "Look of each value the source gives, by value";
                  items = opt (types.listOf (
                    types.submodule {
                      options = {
                        id = mkOption {
                          type = types.str;
                          description = "What the source's `value` names when it is in use, and what `select` is given";
                        };
                        label = opt types.str "Name shown; unset, the id";
                        icon = opt types.str "Glyph shown";
                        detail = opt types.str "Data on the right";
                      };
                    }
                  )) "Items that never change; the source's `value` names the one in use and `enabled` those that can be picked";
                  shortcut = opt types.str "Compositor key, shown in the header while Super is held";
                };
              };
              default = { };
              description = "Passed to the plugin as `settings`, read through its Settings.qml";
            };
          };
        }
      );
      default = { };
      description = "Optional parts of the shell, by the name `status` and `activeWhen` use";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      {
        assertion = manySources == [ ];
        message = "programs.quick-key.settings.plugins: ${toString manySources} set more than one of watch, read and file; set one";
      }
      {
        assertion = everyWithoutRead == [ ];
        message = "programs.quick-key.settings.plugins: ${toString everyWithoutRead} set every without read";
      }
      {
        assertion = lib.intersectLists pluginNames builtinNames == [ ];
        message = "programs.quick-key.settings.plugins: ${toString (lib.intersectLists pluginNames builtinNames)} are built-in names";
      }
      {
        assertion = lib.all (name: lib.elem name (headerItems ++ pluginNames)) headerNames;
        message = "programs.quick-key.settings.menu.header: ${
          toString (lib.filter (name: !(lib.elem name (headerItems ++ pluginNames))) headerNames)
        } are neither built in nor plugins";
      }
    ]
    ++ levelAssertions "the top level" (lib.optionals (settings.menu.entries != null) settings.menu.entries);
  };
}
