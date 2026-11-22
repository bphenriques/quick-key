# Configuration

Everything is optional. `$XDG_CONFIG_HOME/quick-key/config.json` holds what you change, grouped by feature like waybar's modules (`clock`, `audio`, `notifications`, ...), and the shell reloads it on save, keeping what you chose while it ran: keep awake, unsent drafts, a list's order, an open conversation. With Nix, `programs.quick-key.settings` writes it as given. The [reference](options.md) lists every setting and its default.

```json
{
  "theme": { "name": "nord", "monospaceFont": "JetBrainsMono Nerd Font" },
  "clock": { "format": "%A, %-d%o %B %H:%M" },
  "plugins": { "vpn": { "type": "command", "watch": "my-vpn-status", "activate": "my-vpn-toggle", "show": { "up": { "active": true } } } }
}
```

## Checking

`qs -p <the shell's folder>/check.qml` checks `config.json` and shows nothing: it prints what is wrong (a setting that does not exist, a value of another kind, a menu entry or plugin that cannot work) and exits 1. The shell logs the same as it starts. With Nix, the module runs it as the configuration builds, so a wrong setting fails the build, not the session.

## Themes

`theme.name` picks a theme: a file in `$XDG_CONFIG_HOME/quick-key/themes/`, else a shipped preset (`catppuccin-mocha`, `catppuccin-latte`, `gruvbox-dark`, `nord`, `tokyo-night`). A theme holds five colours, and optionally `border` for outlines and dividers, which is otherwise the foreground at `disabledOpacity` so that tint is left to state, and `bubble` and `bubbleText` for your messages in a conversation, otherwise a faint foreground and the text colour:

```json
{ "background": "#2e3440", "foreground": "#d8dee9", "primary": "#88c0d0", "alert": "#bf616a", "warning": "#ebcb8b" }
```

A colour set in `theme` itself wins over the theme's. Anything that writes the file works: a matugen or pywal template for colours from the wallpaper, or, with Nix, `programs.quick-key.themes.<name>`. A misspelt name logs a warning, and fails the build on Nix.

With [stylix](https://github.com/nix-community/stylix), the module themes the shell like one of stylix's own targets: on whenever stylix themes every target (`stylix.autoEnable`), else with `stylix.targets.quick-key.enable = true`. It sets the colours (`border` from `base03`), the monospace font, and the popups' font size and opacity, each as a default your own `theme` settings override. Stylix's popups are opaque by default, which hides the background blur; `stylix.opacity.popups = 0.92` keeps it.

`glyphs` overrides any icon by its name in the kit's `Glyphs` (`{ "wifi": "<glyph>", "audioDevices": { "headset": "<glyph>" } }`): one glyph, a list of them (`batteryLevels`, one per 10%), or a map; the check names one that does not exist.

## Defaults

Unset, the menu is a starter one (audio, network, Bluetooth, music), with the calendar on the clock, the tray and the session in its bar; a bar slot left unset is the starter's. Volume, mute, Wi-Fi and Bluetooth power, and playback are built-in actions (see [Menu](menu.md)), no tool needed; the rest use standard tools from `PATH`, which the Nix module puts first on the shell's `PATH` so they resolve the same on every machine:

| Feature | Tool |
|---|---|
| Brightness | the first `/sys/class/backlight` device, `busctl` |
| Bluetooth, when rfkill blocks it | `rfkill` |
| Keep awake | none: Wayland's idle inhibitor, which the compositor holds for every idle daemon |
| Power profiles, where their daemon is | `busctl`, to see it on the system bus |
| Session | `loginctl`, `systemctl` |
| Calendar reminders | `notify-send` |
| Battery warnings | `notify-send` |
| The `ask` plugin's notifications and pasted images | `notify-send`, `wl-paste` |

`popups.show` lists the statuses or plugins whose changes pop up (`sink`, `source`, `brightness`, `keyboardLayout`, `keepAwake` by default), so another on-screen display can take any of them over; `battery` pops up as it is plugged in or out, not at every percent. A plugin shows as a pill with its glyph and text; one whose text changes constantly (a recording's timer) pops up on every change, so list only plugins that change rarely.

As the charge falls to `battery.low` or `battery.critical` on battery, `battery.warn` is given a title and a line (`Battery low`, `18% left`), once each, never for the charge the shell starts with; empty, no warnings.

Setting `menu.entries` replaces the starter menu whole. To start from it, copy [`menu.json`](https://github.com/bphenriques/quick-key/blob/main/packages/quick-key/menu.json): it is a valid `config.json`. Do-not-disturb (the `dunst` plugin, or your own) and display layouts are plugins you list ([Plugins](plugins.md)).
