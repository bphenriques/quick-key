# Menu

Every key visible, then its status, labels starting together after a gutter as wide as the longest key in their column. A letter opens a level or runs a command; Esc closes, Backspace goes back. A key pair (`[ "Down" "Up" ]` with one command each) shares a row. A level can also list things found at runtime under its actions, numbered 1 to 9: `list = "tray"`, `"bluetooth"`, `"wifi"`, `"sinks"`, `"sources"` or a plugin's name, with `pins` for items that keep their digit. A list with nothing in it says why in its place (`No paired devices`, `No saved networks in range`), unless the header already does (off). `requires.connected` and `requires.enabled` dim an entry until the outputs it needs are plugged in or on. A level that takes keys beyond its rows lists them on one line under its header (`KeyLegend`), with the level's actions on the right of it, from the same list that handles them: the calendar's, and Ctrl+digit for a tray app's menu. `menu toggleEntry <key>` over IPC opens a top-level entry directly, for a compositor shortcut; Backspace still leads to the top level.

The header is `menu.header.left`, `center` and `right`, like waybar's modules: built-in items (`clock`, `keepAwake`, `keyboardLayout`, `battery`) and plugins, by name. The centre is as wide as its items and centred, the sides share the rest, so the menu holds still; crowded, text shortens with an ellipsis, the centre's first, while icons and short values (`80%`, `EN`) stay whole. Inside a level the left holds its title, the right its state. The clock takes `clock.format`, strftime as waybar's (`%A, %-d%o %B %H:%M`, `%o` the English ordinal), else the locale's long date; `clock.locale` (`en_GB`) names days and months for the clock and the calendar, else the system's.

The mouse reaches what the keys do, nothing more: a click runs a row, a right click opens a tray app's menu, the wheel steps a row's pair (volume, brightness) or the calendar's month, a click on a day selects it, the title goes back (at the top, the clock opens the calendar), and a click on a header item flips it (keep awake, keyboard layout) or calls a plugin's `activate()`. Holding Super for a second shows their compositor keys (each feature's `shortcut`, set by the module that binds it, or a plugin's).

An entry runs a command (`cmd`) or a built-in action (`action`), which the shell does through its own services, no tool needed: `sinkVolume` and `sourceVolume` (a pair, by `audio.step` up to `audio.max`), `sinkMute`, `sourceMute`, `brightness` (a pair, the one that runs a tool: `brightness.adjust`), `wifi` and `bluetooth` (power), `playPause`, `track` (a pair), `repeat` and `shuffle` (the music player), `keepAwake` and `keyboardLayout`. An action brings its icon and what lights it, both yours to override, keeps the menu open unless `keepOpen` is false, and dims while it has nothing to act on (no player, no adapter). A pair's first key steps down or back, as in `[ "Down" "Up" ]` and `[ "Left" "Right" ]`.

## An entry

```nix
{
  key = "a";
  desc = "Audio output";
  status = "sink";    # shown in place of the label: the output in use and its volume
  list = "sinks";     # its level lists the outputs, on digits
  submenu = [         # and its actions, on letters
    { key = [ "Down" "Up" ]; desc = "Volume"; action = "sinkVolume"; }   # built in: brings its icon and dims without an output
    { key = "m"; desc = "Mute"; action = "sinkMute"; }                   # lit while muted, by the state it brings
    { key = "c"; desc = "Configure..."; icon = "<glyph>"; cmd = "pavucontrol"; }
  ];
}
```

## Built-in names

Each field takes one of its column's names, or a plugin's. `activeWhen` lights an entry of your own; an `action` already brings its state.

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
