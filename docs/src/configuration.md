# Configuration

Everything is optional. `$XDG_CONFIG_HOME/quick-key/config.json` holds what you change, grouped by feature like waybar's modules (`clock`, `audio`, `notifications`, ...), and the shell reloads it on save. With Nix, `programs.quick-key.settings` writes it. The [options reference](options.md) lists every setting and what applies when it is unset.

```json
{
  "theme": { "name": "nord", "monospaceFont": "JetBrainsMono Nerd Font" },
  "clock": { "format": "%A, %-d%o %B %H:%M" },
  "plugins": { "vpn": { "type": "command", "watch": "my-vpn-status", "activate": "my-vpn-toggle", "show": { "up": { "active": true } } } }
}
```

## Themes

`theme.name` picks a theme: a file in `$XDG_CONFIG_HOME/quick-key/themes/`, else a shipped preset (`catppuccin-mocha`, `catppuccin-latte`, `gruvbox-dark`, `nord`, `tokyo-night`). A theme holds five colours:

```json
{ "background": "#2e3440", "foreground": "#d8dee9", "primary": "#88c0d0", "alert": "#bf616a", "warning": "#ebcb8b" }
```

A colour set in `theme` itself wins over the theme's. Anything that writes the file works: a matugen or pywal template for colours from the wallpaper, or, with Nix, `programs.quick-key.themes.<name>` (from stylix, for example). A misspelt name logs a warning, and fails the build on Nix.

## Defaults

Unset, the menu is a starter one (audio, network, Bluetooth, music, calendar, tray, session). Volume, mute, Wi-Fi and Bluetooth power, and playback are built-in actions (see [Menu](menu.md)), no tool needed; the rest use standard tools from `PATH`, which the Nix module puts first on the shell's `PATH` so they resolve the same on every machine:

| Feature | Tool |
|---|---|
| Brightness | the first `/sys/class/backlight` device, `brightnessctl` |
| Bluetooth, when rfkill blocks it | `rfkill` |
| Keep awake | `systemd-inhibit` |
| Session | `loginctl`, `systemctl` |
| Calendar reminders | `notify-send` |
| The `ask` plugin's notifications and pasted images | `notify-send`, `wl-paste` |

`popups.show` lists the changes that pop up (`sink`, `source`, `brightness`, `keyboardLayout`, `keepAwake`; all by default), so another on-screen display can take any of them over.

Setting `menu.entries` replaces the starter menu whole. To start from it, copy [`menu.json`](https://github.com/bphenriques/quick-key/blob/main/packages/quick-key/menu.json): it is a valid `config.json`. Do-not-disturb (the `dunst` plugin, or your own) and display layouts are plugins you list ([Plugins](plugins.md)).
