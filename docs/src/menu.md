# Menu

The menu is a list of levels. Each is an optional bar floating over its body: the body lists entries, each with a key and a label, that either do something or open a level of their own; the bar holds what you glance at.

```nix
{
  key = "a";
  desc = "Audio output";
  status = "sink";    # on the right of its row: the output in use and its volume
  list = "sinks";     # its level lists the outputs, on digits, each with its volume
  submenu = [         # and its actions, on letters
    { key = [ "Down" "Up" ]; desc = "Volume"; action = "sinkVolume"; }
    { key = "m"; desc = "Mute"; action = "sinkMute"; }
    { key = "c"; desc = "Configure..."; icon = "<glyph>"; cmd = "pavucontrol"; }
  ];
}
```

## Keys

- A letter runs its entry or opens its level. `Esc` closes the menu, `Backspace` goes back.
- Digits pick from a level's list; `Alt+digit` opens an item's own menu (a tray app's).
- `Ctrl` reaches the bar: a bar entry with `key = "c"` runs on `C-c`, a list in it on `C-1` to `C-9`, and `C-M-1` opens an item's own menu there. Holding `Ctrl` for a second lists the bar's keys in place of the body, each with its name.
- Two keys with a command or action each (`[ "Down" "Up" ]`) share a row; the first steps down or back, so a pair reads lesser or earlier side first: `↓↑` is less then more, `←→` and `↑↓` are back then forward, up going back in time as on a scrolled page.
- `Ctrl` and `Alt` may prefix a key in the body (`Ctrl+Left`) where its bar does not take it. Hints show keys Emacs-style: `C-←`, `M-k`, `RET`, `DEL`.
- Holding `Super` for a second lists each bar entry's `shortcut` the same way, the compositor key bound to it.
- `?` lists the keys no row shows: the holds, `M-1` for an item's own menu, `DEL`, `ESC` and, on a level with an input, `C-S-RET`; any key closes it.
- `menu toggleEntry <key>` over IPC opens a top-level entry, in the body or the bar, for a compositor shortcut.

## What an entry does

One of:

- `cmd`: a shell command. The menu closes, unless `keepOpen = true`.
- `action`: a built-in action (below). It brings its icon, which shows its state (Wi-Fi off), and what lights it, keeps the menu open, and dims while it has nothing to act on (no player, no adapter).
- `submenu`, `list` or `view`: a level. `list` adds items found at runtime on digits, `pins` keeps chosen ones on their digit, and `view = "calendar"` shows the [calendar](calendar.md).

The label is `desc`, and never changes. `status` shows live state on the right of the row, short by default, or beside the label for an action in its level (Brightness 55%); `format` picks its fields instead (`"{song}"`), and what follows a `|` stays whole on the right (`"{title}|{when}"`). `activeWhen` lights an entry of your own, and `icon` sets its glyph. A level is as wide as its entry's `width`, else `menu.width`.

## Bars

`menu.header.left`, `center` and `right` are the top level's bar, like waybar's modules, each unset slot the starter's (`menu.json`); an entry's `header` is its level's, with the same slots, and a level without one is its body alone. A slot holds entries and, by name, statuses and plugins (a click calls a plugin's `activate`). An entry shows its status, else its icon, and in a bar may do nothing but show its status. An entry with a `list` shows each item: the tray shows each app's icon, up to its `limit` (nine at most), and past that `+N` on `C-0` shows them all in `menu.picker`; `theme.monochromeTray` draws the icons in greys. An app's own menu has a bar of its own: the app's icon and name, and the submenus opened since (`blueman › Plugins`). Crowded, text shortens; icons and short values stay whole.

```nix
menu.header.left = [ { key = "c"; desc = "Calendar"; status = "clock"; view = "calendar"; } ];
menu.header.right = [ "battery" { desc = "Tray"; list = "tray"; limit = 5; } ];
```

The `clock` status takes `clock.format` (strftime as waybar's, plus `%o` for the English ordinal), else the locale's long date. `clock.locale` names days and months.

## Input

An entry's `input` floats a line of text under its level's body, a bar entry's too. Its key or a click focuses it: `RET` sends and keeps it focused, `C-S-RET` sends and closes the menu, `ESC` clears it, then leaves it; unsent text stays until sent or cleared. Focused, its keys show in the level's legend. The text goes to `cmd` as `$1`, else to `plugin`, else to the plugin the level lists (tasks adds it as a task).

```nix
{ key = "k"; desc = "Tasks"; list = "tasks"; input = { key = "a"; desc = "Add a task"; }; }
```

`format` wraps the text (`{text}`), and `after` runs, given nothing, once the write is done: `cmd` exiting 0, a task added, Ask answering. A command reports its own failure (`notify-send`). Given to [Ask](plugins.md#ask), the input's island is the working area and the body the committed one: while the turn runs the input shows a spinner and takes no text, then the answer shows on a line above it, staying while the next send runs (in alert when it failed, the text given back for `RET` to retry), and the level redraws with what happened. While you stay on the level, the next send continues the conversation, so you can answer a quick question; leaving or closing ends it. `C-S-RET` leaves the answer to a notification. A click on the answer, or Ask's key, opens the whole conversation. An input writes, never filters; put an agent's only on a level showing what it changes:

```nix
{
  key = "c"; desc = "Calendar"; status = "clock"; view = "calendar";
  input = {
    key = "a"; desc = "Add an event"; plugin = "assistant"; after = "calendar-sync";
    format = "Add this event to my calendar, or nothing if it has no day: {text}";
  };
}
```

## Mouse

The mouse reaches what the keys do: a click runs a row or a bar item, a right click opens a tray app's menu or, beside the rows, goes back a level, and the wheel steps a pair (volume, brightness) or the calendar's month. Resting on an icon in a bar names it.

## Built-in names

Each field takes one of its column's names, or a plugin's. A plugin's status gives `format` its `text`, `detail` and fields of its own.

| | `status` | its fields | `list` | `action` | `activeWhen` |
|---|---|---|---|---|---|
| Audio output | `sink` | `device`, `volume` | `sinks` | `sinkVolume`, `sinkMute` | `sinkMuted` |
| Audio input | `source` | `device`, `volume` | `sources` | `sourceVolume`, `sourceMute` | `sourceMuted` |
| Network | `network` | `name`, `wifi` | `wifi` | `wifi` | `wifi` |
| Bluetooth | `bluetooth` | `device`, `battery`, `state` | `bluetooth` | `bluetooth` | `bluetooth` |
| Backlight | `brightness` | `level` | | `brightness` | |
| Music | `music` | `song`, `title`, `artist`, `state` | | `playPause`, `track`, `repeat`, `shuffle` | `repeat`, `shuffle` |
| Tray | | | `tray` | | |
| Calendar | `calendar` | `title`, `when`, `updated` | | | |
| Clock | `clock` | `date` | | | |
| Battery | `battery` | `level` | | | |
| Keyboard layout | `keyboardLayout` | `layout` | | `keyboardLayout` | |
| Keep awake | `keepAwake` | | | `keepAwake` | `keepAwake` |
| Any list | | | | `pick` | |

Volume steps by `audio.step` up to `audio.max`. `brightness` and `pick` are the actions that run a tool: `brightness.adjust`, and `menu.picker`, a dmenu-like command such as `fuzzel --dmenu`.

`pick`, on `space` by rule, shows its level's whole list in `menu.picker`, past the nine on digits, and the chosen item runs as its digit would.
