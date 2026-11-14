# quickkey

[![Nix Flakes](https://img.shields.io/badge/Nix-flakes-5277C3?logo=nixos&logoColor=white)](https://nixos.org/)
[![Docs](https://img.shields.io/badge/docs-site-blue)](https://bphenriques.github.io/quickkey)
[![Status](https://img.shields.io/badge/status-unstable-orange)](#)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue)](LICENSE)

A keyboard-driven [Quickshell](https://quickshell.org) menu with live status, in the style of [`wlr-which-key`](https://github.com/MaxVerevkin/wlr-which-key), plus pop-ups for volume, brightness, keyboard layout and keep-awake. Configured from a home-manager module.

Example:
```nix
{ inputs, ... }:
{
  imports = [ inputs.quickkey.homeManagerModules.default ];

  programs.quickkey = {
    enable = true;
    calendarSync.enable = true;
    settings = {
      clock.format = "%A, %-d%o %B %H:%M";
      integrations.workspace-map = { };   # niri workspace minimap
      menu.entries = [
        { key = "t"; desc = "Tray"; status = "tray"; list = "tray"; }
        { key = "c"; desc = "Calendar"; status = "calendar"; view = "calendar"; }
      ];
    };
  };
}
```

Bind `"${config.programs.quickkey.exec.ipc} menu toggle"` to a compositor key to open it. More in the [docs](https://bphenriques.github.io/quickkey).

I built it for my own [desktop](https://github.com/bphenriques/dotfiles). It is open by design and if this project intrigues and interests you let me know!

> [!WARNING]
> **Work in progress.** Linux and niri only for now, and the option surface still moves.

## Support

I don't expect anything back but if it saved you time and you feel like it, [buy me a coffee](https://buymeacoffee.com/bphenriques) ☕

## AI Disclaimer

I drive the architecture, the design, and the scope. AI has been invaluable to learn and iterate faster. I still take pride in giving my own voice to documentation and tweaking code by hand.

## License

MIT
