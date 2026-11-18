# Getting started

Needs [Quickshell](https://quickshell.org) 0.3 or later, a [Nerd Font](https://www.nerdfonts.com) for the icons, and PipeWire. niri adds the keyboard layout and output details (see [Compositor](compositor.md)).

## With Nix

Add the flake:

```nix
{
  inputs.quick-key.url = "github:bphenriques/quick-key/v0.7.0";
  inputs.quick-key.inputs.nixpkgs.follows = "nixpkgs";
  inputs.quick-key.inputs.home-manager.follows = "home-manager";
}
```

A tag pins a release, whose notes list what changed in the options; leave it off to follow `main`.

Import the module in home-manager and enable it:

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

The module runs it as its own user service, `quick-key`, bound to the Wayland session target and restarted when the configuration changes; a Quickshell config of your own (a bar) runs beside it. Bind `"${config.programs.quick-key.exec.ipc} menu toggle"` to a compositor key. The standard tools its defaults use come first on the service's `PATH`, and `extraPackages` before them: what your plugins and commands call by name (`config.services.dunst.package` for the `dunst` plugin), or your own build of a standard tool.

The config that owns a tool adds its entries and settings next to it (`lib.mkOrder` keeps the top level in order), so the menu grows with the desktop rather than in one file.

## Without Nix

Clone the repository, link the shell into Quickshell's configs and start it with the session:

```sh
git clone https://github.com/bphenriques/quick-key ~/.local/share/quick-key
ln -s ~/.local/share/quick-key/packages/quick-key ~/.config/quickshell/quick-key
```

```kdl
// niri
spawn-at-startup "qs" "-c" "quick-key"
binds {
    Mod+Space { spawn "qs" "-c" "quick-key" "ipc" "call" "menu" "toggle"; }
}
```

It runs without a config: see [Configuration](configuration.md) to change anything.
