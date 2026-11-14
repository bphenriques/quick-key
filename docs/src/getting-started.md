# Getting started

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
    settings.menu.entries = [
      { key = "t"; desc = "Tray"; status = "tray"; list = "tray"; }
    ];
  };
}
```

The module runs Quickshell as a user service bound to the Wayland session target. Bind `"${config.programs.quickkey.exec.ipc} menu toggle"` to a compositor key to open the menu.

The config that owns a tool adds its entries and settings next to it (`lib.mkOrder` keeps the top level in order), so the menu grows with the desktop rather than in one file.
