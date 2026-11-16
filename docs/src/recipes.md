# Recipes

Short configs for the common shapes, each to adapt. They are written for `programs.quick-key.settings`; a plain `config.json` takes the same keys. `<glyph>` stands for a Nerd Font glyph.

## Run a command

```nix
menu.entries = [
  { key = "l"; desc = "Lock"; icon = "<glyph>"; cmd = "loginctl lock-session"; }
];
```

The menu closes as it runs; `keepOpen = true` keeps it open, for a command you repeat.

## A level of commands

```nix
{ key = "s"; desc = "Screenshot"; icon = "<glyph>"; submenu = [
  { key = "s"; desc = "Screen"; icon = "<glyph>"; cmd = "grim"; }
  { key = "r"; desc = "Region..."; icon = "<glyph>"; cmd = ''grim -g "$(slurp)"''; }
  { key = [ "Left" "Right" ]; desc = "Wallpaper"; icon = "<glyph>"; cmd = [ "wallpaper previous" "wallpaper next" ]; keepOpen = true; }
]; }
```

Two keys with a command each share a row.

## Open an entry from a compositor key

```kdl
// niri
Mod+P { spawn "qs" "-c" "quick-key" "ipc" "call" "menu" "toggleEntry" "d"; }
```

`d` is the entry's key. With Nix, `"${config.programs.quick-key.exec.ipc} menu toggleEntry d"`.

## A value beside a label

```nix
plugins.load = {
  type = "command";
  read = ''printf '{"detail": "%s"}' "$(cut -d' ' -f1 /proc/loadavg)"'';
  every = 2;   # seconds, only while the menu is open
};
menu.entries = [
  { key = "p"; desc = "Processes..."; status = "load"; cmd = "foot btop"; }
];
```

`detail` sits on the right of the label. A plain line (`0.42`) would take the label's place instead.

## A toggle that lights

```nix
plugins.nightLight = {
  type = "command";
  read = "systemctl --user is-active wlsunset";
  show.active.active = true;
};
menu.entries = [
  { key = "n"; desc = "Night light"; icon = "<glyph>"; activeWhen = "nightLight"; keepOpen = true;
    cmd = "systemctl --user is-active -q wlsunset && systemctl --user stop wlsunset || systemctl --user start wlsunset; qs -c quick-key ipc call nightLight refresh"; }
];
```

A `read` source is read as the menu opens, so the command asks for another read once it is done. A tool with events needs none: give it as `watch`.

## Pick one of a few

```nix
plugins.powerProfile = {
  type = "command";
  read = "powerprofilesctl get";
  select = "powerprofilesctl set";   # given the item's id
  items = [
    { id = "power-saver"; label = "Power saver"; icon = "<glyph>"; }
    { id = "balanced"; label = "Balanced"; icon = "<glyph>"; }
    { id = "performance"; label = "Performance"; icon = "<glyph>"; }
  ];
};
menu.entries = [
  { key = "p"; desc = "Power profile"; status = "powerProfile"; list = "powerProfile"; }
];
```

The items take the digits; the one the source names is lit, and is what the entry shows.

## Items that come and go

```nix
plugins.containers = {
  type = "command";
  read = ''podman ps --format json | jq -c '{items: map({id: .Names[0], label: .Names[0], detail: .Status})}' '';
  select = "podman restart";
};
menu.entries = [
  { key = "c"; desc = "Containers"; icon = "<glyph>"; list = "containers"; }
];
```

The state line carries the items when the settings list none.

## State a script writes

```nix
plugins.backup = {
  type = "command";
  file = "backup";   # under $XDG_RUNTIME_DIR
  show.running = { text = "Backing up"; active = true; };
};
```

The script writes `running` to the file as it starts and empties it as it ends; the shell reads it on every change, with nothing running in between.

## In the header

```nix
plugins.dunst = { };
menu.header.right = [ "dunst" "keepAwake" "keyboardLayout" "battery" ];
```

A plugin in the header shows its glyph, lit while active; a click calls its `activate`. Any `command` plugin works the same.

## Keep a device on its digit

```nix
{ key = "a"; desc = "Audio output"; status = "sink"; list = "sinks";
  pins = [
    { match = "alsa_output.pci-*"; label = "Speakers"; }
    { match = "bluez_output.*"; label = "Headphones"; }
  ];
  submenu = [ { key = [ "Down" "Up" ]; desc = "Volume"; action = "sinkVolume"; } ];
}
```

Pins take the digits from 1, dimmed while absent, so `a 2` is always the headphones.
