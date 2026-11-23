# Getting started

Needs [Quickshell](https://quickshell.org) 0.3 or later, PipeWire, and a [Nerd Font](https://www.nerdfonts.com) for the icons: `theme.monospaceFont` names it, and without one the icons show as boxes. niri adds the keyboard layout and output details; elsewhere the rest works (see [Compositor](compositor.md)).

## Install with Nix

Add the flake, pinned to a [release](https://github.com/bphenriques/quick-key/releases), whose notes list what changed in the options:

```nix
{
  inputs.quick-key.url = "github:bphenriques/quick-key/<release tag>";
  inputs.quick-key.inputs.nixpkgs.follows = "nixpkgs";
  inputs.quick-key.inputs.home-manager.follows = "home-manager";
}
```

Leave the tag off to follow `main`. Import the module in home-manager and enable it:

```nix
{ inputs, ... }:
{
  imports = [ inputs.quick-key.homeModules.default ];

  programs.quick-key = {
    enable = true;
    settings.theme.name = "catppuccin-mocha";
  };
}
```

The module runs it as its own user service, `quick-key`, bound to the Wayland session target and restarted when the configuration changes. A Quickshell config of your own (a bar) runs beside it.

Commands run on the service's `PATH`: `extraPackages` first, then the standard tools the defaults use, then the session's. Put in `extraPackages` what your commands, plugins and notification rules call by name (`config.services.dunst.package` for the `dunst` plugin).

## Install without Nix

Clone the repository, link the shell into Quickshell's configs and start it with the session:

```sh
git clone https://github.com/bphenriques/quick-key ~/.local/share/quick-key
ln -s ~/.local/share/quick-key/packages/quick-key ~/.config/quickshell/quick-key
```

```kdl
// niri
spawn-at-startup "qs" "-c" "quick-key"
```

## Bind a key

One key opens the menu:

```kdl
// niri
binds {
    Mod+Space { spawn "qs" "-c" "quick-key" "ipc" "call" "menu" "toggle"; }
}
```

With Nix, the same through `exec.ipc`, a command line that needs a shell: `Mod+Space { spawn-sh "${config.programs.quick-key.exec.ipc} menu toggle"; }`.

## First run

It runs without a config. The starter menu holds audio, network, Bluetooth and music, with the calendar on the clock and the tray and the session in its bar. Press its key: each row's letter runs it, `ESC` goes back, and `?` lists every key (see [Menu](menu.md)).

## Check and logs

`qs -p <the shell's folder>/check.qml` checks `config.json`, printing what is wrong and exiting 1 (see [Configuration](configuration.md#checking)). With Nix it runs as the configuration builds, so a mistake fails the build, not the session.

The shell logs the same as it starts, and every warning after: `journalctl --user -u quick-key` with the module, else Quickshell's own log (`qs log -c quick-key`).

## First change

Add a row of your own. Start from the starter's entries in `~/.config/quick-key/config.json` ([Extend the starter](recipes.md#extend-the-starter)), then append one to `menu.entries`:

```json
{ "key": "l", "desc": "Lock", "icon": "󰌾", "cmd": "loginctl lock-session" }
```

With Nix, the config that owns a tool adds its entries next to it (`lib.mkOrder` keeps the top level in order), so the menu grows with the desktop rather than in one file.

## Next

- [Recipes](recipes.md): short configs to adapt, from a command to a plugin.
- [Configuration](configuration.md): themes, defaults and what is kept.
- [Plugins](plugins.md): status and actions from any command.
