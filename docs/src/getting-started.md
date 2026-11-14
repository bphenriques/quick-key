# Getting started

Needs [Quickshell](https://quickshell.org) 0.3 or later, a [Nerd Font](https://www.nerdfonts.com) for the icons, and PipeWire. niri adds the keyboard layout and output details (see [Compositor](compositor.md)).

## With Nix

Add the flake:

```nix
{
  inputs.quickkey.url = "github:bphenriques/quickkey";
  inputs.quickkey.inputs.nixpkgs.follows = "nixpkgs";
}
```

Import the module in home-manager and enable it:

```nix
{ inputs, ... }:
{
  imports = [ inputs.quickkey.homeManagerModules.default ];

  programs.quickkey = {
    enable = true;
    settings.theme.name = "catppuccin-mocha";
  };
}
```

The module runs Quickshell as a user service bound to the Wayland session target, restarted when the configuration changes. Bind `"${config.programs.quickkey.exec.ipc} menu toggle"` to a compositor key.

The config that owns a tool adds its entries and settings next to it (`lib.mkOrder` keeps the top level in order), so the menu grows with the desktop rather than in one file.

## Without Nix

Clone the repository, link the shell into Quickshell's configs and start it with the session:

```sh
git clone https://github.com/bphenriques/quickkey ~/.local/share/quickkey
ln -s ~/.local/share/quickkey/packages/quickkey ~/.config/quickshell/quickkey
```

```kdl
// niri
spawn-at-startup "qs" "-c" "quickkey"
binds {
    Mod+Space { spawn "qs" "-c" "quickkey" "ipc" "call" "menu" "toggle"; }
}
```

It runs without a config: see [Configuration](configuration.md) to change anything.
