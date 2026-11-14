# Configuration

Everything is optional. `$XDG_CONFIG_HOME/quickkey/config.json` holds what you change, grouped by feature like waybar's modules (`clock`, `audio`, `notifications`, ...), and the shell reloads it on save. With Nix, `programs.quickkey.settings` writes it. The [options reference](options.md) lists every setting and what applies when it is unset.

```json
{
  "theme": { "name": "nord", "monospaceFont": "JetBrainsMono Nerd Font" },
  "clock": { "format": "%A, %-d%o %B %H:%M" },
  "plugins": { "doNotDisturb": { "settings": { "watch": "my-dnd-status", "activate": "my-dnd-toggle" } } }
}
```

## Themes

`theme.name` picks a theme: a file in `$XDG_CONFIG_HOME/quickkey/themes/`, else a shipped preset (`catppuccin-mocha`, `catppuccin-latte`, `gruvbox-dark`, `nord`, `tokyo-night`). A theme holds five colours:

```json
{ "background": "#2e3440", "foreground": "#d8dee9", "primary": "#88c0d0", "alert": "#bf616a", "warning": "#ebcb8b" }
```

A colour set in `theme` itself wins over the theme's. Anything that writes the file works: a matugen or pywal template for colours from the wallpaper, or, with Nix, `programs.quickkey.themes.<name>` (from stylix, for example). A misspelt name logs a warning, and fails the build on Nix.

## Defaults

Unset, the menu is a starter one (audio, network, Bluetooth, calendar, tray, session), and features use standard tools from `PATH`:

| Feature | Tool |
|---|---|
| Volume, mute | `wpctl` |
| Wi-Fi, Bluetooth power | `nmcli`, `rfkill` |
| Brightness | the first `/sys/class/backlight` device, `brightnessctl` |
| Keep awake | `systemd-inhibit` |
| Session | `loginctl`, `systemctl` |
| Calendar reminders | `notify-send` |

`popups.show` lists the changes that pop up (`sink`, `source`, `brightness`, `keyboardLayout`, `keepAwake`; all by default), so another on-screen display can take any of them over.

Setting `menu.entries` replaces the starter menu whole. To start from it, copy [`menu.json`](https://github.com/bphenriques/quickkey/blob/main/packages/quickkey/menu.json): it is a valid `config.json`. Do-not-disturb and display layouts have no standard tool, so they are plugins you list with your own commands ([Plugins](plugins.md)).
