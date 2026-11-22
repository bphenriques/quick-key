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
plugins.displays = {
  type = "command";
  read = "display-layout get";     # prints the id in use
  select = "display-layout set";   # given the item's id
  items = [
    { id = "laptop"; label = "Laptop only"; icon = "<glyph>"; }
    { id = "external"; label = "External only"; icon = "<glyph>"; }
    { id = "extend"; label = "Extend"; icon = "<glyph>"; }
  ];
};
menu.entries = [
  { key = "d"; desc = "Display"; status = "displays"; list = "displays"; }
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
  show.running = { text = "Backing up"; phase = "working"; };
  show.failed = { text = "Backup failed"; phase = "error"; };
};
```

The script writes `running` to the file as it starts, then empties it, or writes `failed`; the shell reads it on every change, with nothing running in between. `phase` is how every surface draws work: `working` spins, `error` alerts ([Plugins](plugins.md#sources)).

## A VPN

```nix
plugins.vpn = {
  type = "command";
  read = ''tailscale status --json | jq -r 'if .BackendState == "Running" then "up" else "down" end' '';
  show.up = { glyph = "<glyph>"; text = "connected"; active = true; };
  show.down = { glyph = "<glyph>"; text = "off"; };
  activate = ''tailscale status --json | jq -e '.BackendState == "Running"' > /dev/null && tailscale down || tailscale up; qs -c quick-key ipc call vpn refresh'';
};
menu.header.right = [ "vpn" ];
```

A click on it in the bar toggles it; for a key, make it an entry (`{ key = "v"; desc = "VPN"; status = "vpn"; activeWhen = "vpn"; cmd = "..."; }`). A NetworkManager or WireGuard connection is the same shape: `read` from `nmcli -g GENERAL.STATE connection show wg0`, toggle with `nmcli connection up` and `down`.

## The weather

```nix
plugins.weather = {
  type = "command";
  read = ''curl -sf 'https://wttr.in/?format=%t' '';   # +18°C
  every = 900;
  glyph = "<glyph>";
};
menu.header.center = [ "weather" ];
```

Read as the menu opens and every 15 minutes while it stays open; with no network it shows nothing until the next read. Put a place after the slash (`wttr.in/Lisbon`) to pin it.

## In the bar

```nix
plugins.dunst = { };
menu.header.right = [ "dunst" "battery" ];
```

A plugin in a bar shows its glyph, lit while active; a click calls its `activate`. Any `command` plugin works the same. For a key, make it an entry: `{ key = "d"; desc = "Do not disturb"; status = "dunst"; cmd = "dunstctl set-paused toggle"; }` runs on `C-d`.

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
