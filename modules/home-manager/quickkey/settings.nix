# The schema of config.json, the shell's only input: each option is one of its keys, unset ones left out.
{
  lib,
  pkgs,
  config,
  ...
}:
let
  inherit (lib) mkOption types;

  cfg = config.programs.quickkey;
  inherit (cfg) settings;
  jsonType = (pkgs.formats.json { }).type;

  builtinStatuses = [
    "sink"
    "source"
    "music"
    "network"
    "bluetooth"
    "display"
    "tray"
    "calendar"
  ];
  builtinStates = [
    "wifi"
    "bluetooth"
    "repeat"
    "shuffle"
    "sink-muted"
    "source-muted"
  ];
  headerItems = [
    "clock"
    "notifications"
    "keepAwake"
    "keyboardLayout"
    "battery"
  ];
  # Integrations may not take a built-in name.
  builtinNames = builtinStatuses ++ builtinStates ++ headerItems;
  integrationNames = lib.attrNames settings.integrations;
  headerNames = lib.concatLists (lib.filter (slot: slot != null) (lib.attrValues settings.menu.header));
  displayLayouts = lib.attrNames (if settings.display.layouts == null then { } else settings.display.layouts);

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
  wheel = opt (types.listOf types.str) "Commands the wheel runs, down then up";
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
      keepOpen = mkOption {
        type = types.nullOr types.bool;
        default = null;
        description = "Keep the menu open after running cmd";
      };
      activeWhen = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "State that lights the entry while on, for a toggle: one of ${toString builtinStates}, or an integration's name";
      };
      layout = mkOption {
        type = types.nullOr types.str;
        default = null;
        description = "Display layout the entry selects, lit while current and dim while the connected screens do not allow it";
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
        type = types.nullOr (
          types.enum [
            "tray"
            "bluetooth"
            "wifi"
            "sinks"
            "sources"
          ]
        );
        default = null;
        description = "Nested entries filled at runtime (tray apps, paired Bluetooth devices, saved Wi-Fi networks in range, audio outputs or inputs), numbered after any submenu";
      };
      pins = mkOption {
        type = types.listOf (
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
        );
        default = [ ];
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
        description = "Status shown in place of the label: one of ${toString builtinStatuses}, or an integration's name";
      };
      requires = {
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
        message = "programs.quickkey.settings.menu: duplicate keys in ${path}: ${toString duplicates}";
      }
      {
        assertion = badModifiers == [ ];
        message = "programs.quickkey.settings.menu: only Ctrl+ and Alt+ may prefix a key in ${path}: ${toString badModifiers}";
      }
      {
        assertion = appMenuKeys == [ ];
        message = "programs.quickkey.settings.menu: Ctrl+digit opens a listed item's own menu, so ${toString appMenuKeys} in ${path} cannot be bound";
      }
      {
        assertion = reserved == [ ];
        message = "programs.quickkey.settings.menu: ${toString reserved} in ${path} are reserved for the menu";
      }
    ]
    ++ lib.concatMap (e: [
      {
        assertion = (e.cmd != null) != (e.submenu != null || e.list != null || e.view != null);
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} needs either cmd, submenu and/or list, or view";
      }
      {
        assertion = e.status == null || lib.elem e.status (builtinStatuses ++ integrationNames);
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} shows status '${toString e.status}', neither built in nor an integration's";
      }
      {
        assertion = e.activeWhen == null || lib.elem e.activeWhen (builtinStates ++ integrationNames);
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} is lit by '${toString e.activeWhen}', neither built in nor an integration's";
      }
      {
        assertion = e.layout == null || lib.elem e.layout displayLayouts;
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} selects layout '${toString e.layout}', not one of display.layouts: ${toString displayLayouts}";
      }
      {
        assertion = e.view == null || e.list == null;
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} cannot combine view with list";
      }
      {
        assertion = e.keepOpen == null || e.cmd != null;
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} can only set keepOpen with cmd";
      }
      {
        assertion = e.submenu == null || lib.all (a: a.icon != null) e.submenu;
        message = "programs.quickkey.settings.menu: every action in '${e.desc}' needs an icon";
      }
      {
        assertion = e.pins == [ ] || e.list != null;
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} can only set pins with list";
      }
      {
        assertion = lib.length e.pins <= 9;
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} has more pins than digits";
      }
      {
        assertion = e.list == null || lib.intersectLists digits (keysOf (if e.submenu != null then e.submenu else [ ])) == [ ];
        message = "programs.quickkey.settings.menu: digits in '${e.desc}' are reserved for its list";
      }
      {
        assertion = !(lib.isList e.cmd) || (lib.isList e.key && lib.length e.cmd == lib.length e.key);
        message = "programs.quickkey.settings.menu: '${e.desc}' in ${path} pairs keys and commands, so needs as many of each";
      }
    ]) entries
    ++ lib.concatMap (e: lib.optionals (e.submenu != null) (levelAssertions "${path} > ${e.desc}" e.submenu)) entries;
in
{
  options.programs.quickkey.settings = {
    theme = group "Colours, font and sizes" (
      {
        background = opt types.str "Background colour";
        foreground = opt types.str "Text colour";
        primary = opt types.str "Colour of what is on or in use";
        alert = opt types.str "Colour of what needs attention";
        warning = opt types.str "Colour of what may soon need attention";
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
      entries = mkOption {
        type = types.listOf entry;
        default = [ ];
        description = "Top-level entries, ordered with `lib.mkOrder`";
      };
      header = lib.genAttrs [ "left" "center" "right" ] (
        slot:
        opt (types.listOf types.str) "Items in the header's ${slot} third, like waybar's modules-${slot}: ${toString headerItems} or integrations"
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
      file = opt types.str "Events file the month shows; `calendarSync` sets it";
      remind = opt types.str "Command given an event's title and when, run before each timed event";
      remindBefore = opt types.ints.unsigned "Minutes before a timed event the reminder runs";
    };

    popups = group "The pop-ups for volume, brightness, layout and keep-awake" {
      timeout = opt types.ints.positive "Milliseconds a pop-up stays";
    };

    audio = group "Audio devices" {
      devices = opt types.str "Command printing one device per line: kind (sink or source), name, type and label, tab separated, internal first";
      select = opt types.str "Command given a kind and a device name, making it the default";
      adjust = group "The volume wheel" {
        sink = wheel;
        source = wheel;
      };
      glyphs = glyphs "Glyph by device type (headphones, headset, internal, external, microphone) and microphoneOff";
    };

    brightness = group "The backlight" {
      backlight = opt types.str "Command printing the backlight's value file, a tab, and its maximum";
      adjust = wheel;
    };

    display = group "Outputs and their layouts" {
      status = opt types.str "Command printing the current layout, then the layouts the connected screens allow, one per line";
      layouts = opt (types.attrsOf types.str) "Label by layout, as the Display row shows it";
      panel = opt types.str "Built-in panel the backlight dims: connector name, or make, model and serial";
      glyphs = glyphs "Glyph by layout";
    };

    notifications = group "Do-not-disturb" {
      watch = opt types.str "Command printing true or false for do-not-disturb, then again on every change";
      toggle = opt types.str "Command pausing or resuming notifications";
      inherit shortcut;
    };

    keepAwake = group "Idle inhibition" {
      command = opt types.str "Command inhibiting idle until its stdin closes";
      inherit shortcut;
    };

    keyboardLayout = group "Keyboard layouts" {
      labels = opt (types.listOf types.str) "Short label per layout, in the compositor's order";
      inherit shortcut;
    };

    battery = group "The battery" {
      low = opt (types.ints.between 0 100) "Percentage at which the battery shows as low";
      critical = opt (types.ints.between 0 100) "Percentage at which the battery shows as critical";
      glyphs = group "Battery glyphs" {
        discharging = opt (types.listOf types.str) "Eleven glyphs, empty to full";
        charging = opt (types.listOf types.str) "Eleven glyphs, empty to full";
      };
    };

    music = group "The music status" {
      player = opt types.str "MPRIS identity of the player to follow; unset, the one playing";
      glyphs = glyphs "Glyph for music, shuffle and repeat";
    };

    integrations = mkOption {
      type = types.attrsOf (
        types.submodule {
          options = {
            source = mkOption {
              type = types.nullOr (types.either types.path types.str);
              default = null;
              description = "QML file whose root is an Integration, a path or relative to the shell; unset, the one shipped under this name";
            };
            settings = mkOption {
              type = jsonType;
              default = { };
              description = "Passed to the integration as `settings`";
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
        assertion = lib.intersectLists integrationNames builtinNames == [ ];
        message = "programs.quickkey.settings.integrations: ${toString (lib.intersectLists integrationNames builtinNames)} are built-in names";
      }
      {
        assertion = lib.all (name: lib.elem name (headerItems ++ integrationNames)) headerNames;
        message = "programs.quickkey.settings.menu.header: ${
          toString (lib.filter (name: !(lib.elem name (headerItems ++ integrationNames))) headerNames)
        } are neither built in nor integrations";
      }
    ]
    ++ levelAssertions "the top level" settings.menu.entries;
  };
}
