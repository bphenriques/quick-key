# Configuration

Everything is optional. `$XDG_CONFIG_HOME/quick-key/config.json` holds what you change, grouped by feature like waybar's modules (`clock`, `audio`, `battery`, ...), a plugin's under `plugins.<name>`. The shell reloads it on save; a save that is not JSON (a typo, a write caught halfway) leaves the running config in place and says so in a notification. With Nix, `programs.quick-key.settings` writes it as given. The [reference](options.md) lists every setting and its default.

```json
{
  "theme": { "name": "nord", "monospaceFont": "JetBrainsMono Nerd Font" },
  "clock": { "format": "%A, %-d%o %B %H:%M" },
  "plugins": { "vpn": { "type": "command", "watch": "my-vpn-status", "activate": "my-vpn-toggle", "show": { "up": { "active": true } } } }
}
```

What you choose while logged in is kept over a reload or a restart: keep awake, unsent drafts, a list's order, an open conversation.

The defaults are a suggested setup, not a ceiling. Sizes given in pixels that you leave unset follow `theme.fontSize` (`theme.iconSize`, `menu.width`), so a larger font keeps the proportions; what you set wins. The check bounds each value, and the layout keeps every surface within its screen (no margin past a quarter of it, no menu taller, no more columns than its width holds), so no setting breaks the menu or its keys.

Past the suggested look, settings draw the bar as islands (set wider apart, so a crowded bar needs a wider menu), set titles larger and slide pop-ups in (within their margin, so one at the very edge only fades), within the same limits; the menu itself always appears at once.

## Checking

`qs -p <the shell's folder>/check.qml` checks `config.json` and shows nothing. It prints what is wrong (a setting that does not exist, a value of another kind, a menu entry or plugin that cannot work) and exits 1. The shell logs the same as it starts. With Nix, the module runs it as the configuration builds, so a wrong setting fails the build, not the session; the shell's folder is the package's `share/quick-key`. A plugin linked out of the store (`mkOutOfStoreSymlink`) is beyond the build's reach, so its own settings go unchecked. Without a display, as in CI or over SSH, run it with `QT_QPA_PLATFORM=offscreen`.

## Themes

`theme.name` picks a theme: a file of yours, else a shipped preset. A theme holds five colours, and optionally `border`, `bubble` and `bubbleText`:

```json
{ "background": "#2e3440", "foreground": "#d8dee9", "primary": "#88c0d0", "alert": "#bf616a", "warning": "#ebcb8b" }
```

A colour set in `theme` itself wins over the theme's. Colours are `#rrggbb` (or `#aarrggbb`, alpha first, as Qt reads it); one that is not is skipped with a warning. Anything that writes the file works: your editor, a matugen or pywal template for colours from the wallpaper ([recipe](recipes.md#colours-from-the-wallpaper)), or, with Nix, `programs.quick-key.themes.<name>`. Saving it applies it at once. A misspelt name logs a warning, and fails the build on Nix.

With [stylix](https://github.com/nix-community/stylix), the module themes the shell like one of stylix's own targets: on whenever stylix themes every target (`stylix.autoEnable`), else with `stylix.targets.quick-key.enable = true`. It writes its colours as a theme named `stylix` (`border` from `base03`), picked unless you name another, and sets the monospace font and the popups' font size and opacity, each a default your own `theme` settings override. Stylix's popups are opaque by default, which hides the background blur; `stylix.opacity.popups = 0.92` keeps it.

`glyphs` overrides any icon by its name in the kit's `Glyphs`, in the shape of its default: one glyph, a list (`batteryLevels`, one per 10%), or a map (`{ "audioDevices": { "headset": "<glyph>" } }`).

## Defaults

Unset, the menu is a starter one (audio, network, Bluetooth, music), with the calendar on the clock, and the tray and the session in its bar. Volume, mute, Wi-Fi and Bluetooth power, and playback are built-in actions (see [Menu](menu.md)), no tool needed. The rest use standard tools from `PATH`, which the Nix module puts on the shell's `PATH` ahead of the session's, so they resolve the same on every machine:

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
| The `notifications` plugin, to see it holds the bus | `busctl` |

`popups.show` lists what pops up as it changes, so another on-screen display can take any of it over. Listed, `battery` pops up as it is plugged in or out, not at every percent, and `bluetooth` as it turns on or off or a device connects or leaves, not at every percent of a headset. A plugin pops up as a pill with its glyph and text on every change of its text, so list only plugins that change rarely (not a recording's timer). None shows while a menu or panel is open, which shows the value itself.

`battery.warn` runs once as the charge falls to `battery.low`, and once more at `battery.critical`, never for the charge the shell starts with.

Setting `menu.entries` replaces the starter menu whole. To start from it, copy [`menu.json`](https://github.com/bphenriques/quick-key/blob/main/packages/quick-key/menu.json): it is a valid `config.json`. Do-not-disturb (the `notifications` plugin's pause, the `dunst` plugin, or your own) and display layouts are plugins you list ([Plugins](plugins.md)).
