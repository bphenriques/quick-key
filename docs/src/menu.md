# Menu

The menu is a list of entries. Each has a key and a label, and either does something or opens a level of its own.

```nix
{
  key = "a";
  desc = "Audio output";
  status = "sink";    # shown in place of the label: the output in use and its volume
  list = "sinks";     # its level lists the outputs, on digits
  submenu = [         # and its actions, on letters
    { key = [ "Down" "Up" ]; desc = "Volume"; action = "sinkVolume"; }
    { key = "m"; desc = "Mute"; action = "sinkMute"; }
    { key = "c"; desc = "Configure..."; icon = "<glyph>"; cmd = "pavucontrol"; }
  ];
}
```

## Keys

- A letter runs its entry or opens its level. `Esc` closes the menu, `Backspace` goes back.
- Digits pick from a level's list. `Ctrl+digit` opens a tray app's own menu.
- Two keys with a command or action each (`[ "Down" "Up" ]`) share a row; the first steps down or back.
- `Ctrl` and `Alt` may prefix a key (`Ctrl+Left`). Hints show keys Emacs-style: `C-←`, `M-k`, `RET`, `DEL`.
- Holding `Super` for a second shows the compositor keys each feature is bound to.
- `menu toggleEntry <key>` over IPC opens an entry directly, for a compositor shortcut.

## What an entry does

One of:

- `cmd`: a shell command. The menu closes, unless `keepOpen = true`.
- `action`: a built-in action (below). It brings its icon and what lights it, keeps the menu open, and dims while it has nothing to act on (no player, no adapter).
- `submenu`, `list` or `view`: a level. `list` adds items found at runtime on digits, `pins` keeps chosen ones on their digit, and `view = "calendar"` shows the [calendar](calendar.md).

`status` shows live state in place of the label, `activeWhen` lights an entry of your own, and `icon` sets its glyph. A level is as wide as its entry's `width`, else `menu.width`.

## Header

`menu.header.left`, `center` and `right` hold built-in items (`clock`, `keepAwake`, `keyboardLayout`, `battery`) and plugins, like waybar's modules. Inside a level, the header shows its title and state instead. Crowded, text shortens; icons and short values stay whole.

The clock takes `clock.format` (strftime as waybar's, plus `%o` for the English ordinal), else the locale's long date. `clock.locale` names days and months.

## Mouse

The mouse reaches what the keys do: a click runs a row, a right click opens a tray app's menu, the wheel steps a pair (volume, brightness) or the calendar's month, and the title goes back. At the top, the clock opens the calendar.

## Built-in names

Each field takes one of its column's names, or a plugin's.

| | `status` | `list` | `action` | `activeWhen` | `menu.header` |
|---|---|---|---|---|---|
| Audio output | `sink` | `sinks` | `sinkVolume`, `sinkMute` | `sinkMuted` | |
| Audio input | `source` | `sources` | `sourceVolume`, `sourceMute` | `sourceMuted` | |
| Network | `network` | `wifi` | `wifi` | `wifi` | |
| Bluetooth | `bluetooth` | `bluetooth` | `bluetooth` | `bluetooth` | |
| Backlight | `brightness` | | `brightness` | | |
| Music | `music` | | `playPause`, `track`, `repeat`, `shuffle` | `repeat`, `shuffle` | |
| Tray | `tray` | `tray` | | | |
| Calendar | `calendar` | | | | |
| Battery | `battery` | | | | `battery` |
| Keyboard layout | `keyboardLayout` | | `keyboardLayout` | | `keyboardLayout` |
| Keep awake | `keepAwake` | | `keepAwake` | `keepAwake` | `keepAwake` |
| Clock | | | | | `clock` |

Volume steps by `audio.step` up to `audio.max`. `brightness` is the one action that runs a tool: `brightness.adjust`.
