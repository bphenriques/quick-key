# Menu

The menu is a list of levels. Each is its body over an optional bar at the screen's edge. A body holds one thing: a menu's entries, each with a key and a label, that either do something or open a level of their own, or a level's content, its list or its view (the calendar). A content level's own entries, drawn as their rows a column gap apart, and its legend sit on its bar's left, before its header's left slot, so a list that grows moves neither; when they do not all fit whole, every action shows its key and glyph alone, its label as its tip (one without a glyph keeps its label), never half of them nor a label cut short. The bar also holds what you glance at.

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

Letters are actions and digits are list items.

- A letter runs its entry or opens its level. `ESC` is the one way back, as in a launcher: it clears what you typed, then closes the filter or a focused event, then returns where you came from (the level above, or the panel or input that opened it, focused again), and at the root closes the menu; it never moves the keys, stops or answers anything, and a legend names it only while it clears. A level opened on its own, by a shortcut or a key path, is a root.
- Digits pick from a level's list; `Alt+digit` opens an item's own menu (a tray app's).
- `Ctrl` reaches the bar: a bar entry with `key = "c"` runs on `C-c`, a list in it on `C-1` to `C-9`, and `C-M-1` opens an item's own menu there. Holding `Ctrl` for a second lists the bar's keys in place of the body, each with its name.
- Two keys with a command or action each (`[ "Down" "Up" ]`) share a row; the first steps down or back, so a pair reads lesser or earlier side first: `↓↑` is less then more, `←→` and `↑↓` are back then forward, up going back in time as on a scrolled page. A pair is named for what it changes (`Volume`, `Track`).
- Device levels put Power on `p` and Configure... on `c`. `space` is only ever a picker, and what ends the session takes Shift (Reboot, Shutdown).
- `Ctrl` and `Alt` may prefix a key in the body (`Ctrl+Left`, as niri writes bindings) where its bar does not take it. Hints show keys Emacs-style, `C-` Ctrl, `M-` Alt, `s-` Super, Shift as the capital letter (`C-←→`, `s-k`), symbols for the arrows, `DEL` for Backspace and `ESC` for Escape as Emacs writes them; a modifier never runs the plain key, Shift only picks the capital letter, and Super stays the compositor's.
- Holding `Super` for a second lists each bar entry's `shortcut` the same way, the compositor key bound to it.
- `?` lists the keys no row shows: the holds, `M-1` for an item's own menu, `ESC` and, on a level with an input, `TAB` and `C-S-RET`; any key closes it.
- `menu toggleEntry <key>` over IPC opens a top-level entry, in the body or the bar, for a compositor shortcut.
- `menu press "<path>"` runs a key path from the top level as typing it would (`"a 2"`, `"Ctrl+x"`, keys named as entries declare them), so a binding reaches anything the menu does; a digit is the same item only while pinned. `menu keys` prints every path as Markdown, from `menu.entries` and the top level's bar.

## What an entry does

One of:

- `cmd`: a shell command. The menu closes, unless `keepOpen = true`.
- `action`: a built-in action (below), or one of the plugin its level lists (the tasks' `sort`). It brings its icon, which shows its state (Wi-Fi off), and what lights it, keeps the menu open, and dims while it has nothing to act on (no player, no adapter); what can never run on this machine is not declared.
- `submenu`, `list` or `view`: a level. `list` adds items found at runtime on digits, `pins` keeps chosen ones on their digit, dim while absent, their label naming them wherever the menu shows them (the rest follow by name, internal audio first, never by signal or recency), and `view = "calendar"` shows the [calendar](calendar.md).

The label is `desc`, and never changes; every row of a level carries an icon (`icon`, or an `action`'s own). `status` shows live state on the right of the row, short by default, or beside the label for an action in its level (Brightness 55%); a status names its state only when it has no value to show (`off`, `muted`), and never holds a word there for a state its icon or tone already shows. `format` picks its fields instead (`"{song}"`), and what follows a `|` stays whole on the right (`"{title}|{when}"`). `activeWhen` lights an entry of your own. A level is as wide as its entry's `width`, else `menu.width`, and lays its actions out in its entry's `columns`, else `menu.columns` (`columns = 1` for a level of three, so none sits alone); never measured from what it shows, so it holds still. Entries flow across, so order decides neighbours; at the top the columns are equal, so values line up, and in a level the last hugs its rows against the right edge. Make the menu wider before adding columns or truncating.

## Bars

`menu.header.left`, `center` and `right` are the top level's bar, like waybar's modules, each unset slot the starter's (`menu.json`); an entry's `header` is its level's, with the same slots, and a level with nothing for its bar is its body alone. A bar holds content (a song, its modes), never a title. A slot holds entries and, by name, statuses and plugins (a click calls a plugin's `activate`). An entry shows its status, else its icon, and in a bar may do nothing but show its status; with both, a bar shows its icon, in the status's tone (of what its `format` shows), a spinner while the status is busy, and its value on hover, beside it too while that tone warns, so a Sync button stays out of the way until its sync is under way or stale ([Calendar](calendar.md)). An entry with a `list` shows each item: the tray shows each app's icon, up to its `limit` (nine at most), and past that `+N` on `C-0` shows them all, filtered on a level of their own; `theme.monochromeTray` draws the icons in greys. An app's own menu has a bar of its own: the app's icon and name, and the submenus opened since (`blueman › Plugins`). Crowded, text shortens; icons and short values stay whole.

```nix
menu.header.left = [ { key = "c"; desc = "Calendar"; status = "clock"; view = "calendar"; } ];
menu.header.right = [ "battery" { desc = "Tray"; list = "tray"; limit = 5; } ];
```

The `clock` status takes `clock.format` (strftime as waybar's, plus `%o` for the English ordinal), else the locale's long date. `clock.locale`, else the system's, is the locale every date and time is said in. They are said one way everywhere: a time as the locale writes it (14:30, 2:30 PM), a day as yesterday, today or tomorrow, its weekday within a week either side, else its date (3 Nov), with its year when not this one; short names are cut to three letters where that still tells them apart (Sep, not Sept).

## Input

An entry's `input` floats a line of text over its level's body, a bar entry's too, and `menu.input` over the top level's, a catch-all for what belongs to no level (`menu.input = { desc = "Ask"; plugin = "assistant"; }`). An input takes letters only while focused, so keys hold still: `TAB` moves the keys from the body to the input on every level, as Tab moves between areas anywhere, `TAB` or `S-TAB` back (without an input, both are Qt's), and a click focuses it too: `RET` sends and keeps it focused, `C-S-RET` sends and closes the menu, `ESC` clears it, then steps back; unsent text stays until sent or cleared, closing the menu too. Focused, its keys show on its right. The text goes to `cmd` as `$1`, else to `plugin`, else to the plugin the level lists (tasks adds it as a task); the config says where text goes, and how the write is done (order, retries, reporting) is the command's, never a new field.

```nix
{ key = "k"; desc = "Tasks"; list = "tasks"; input = { desc = "Add a task"; }; }
```

`format` wraps the text that starts a conversation (`{text}`), and `after` runs, given nothing, once the write is done: `cmd` exiting 0, a task added, Ask answering. A command reports its own failure (`notify-send`). Given to [Ask](plugins.md#ask), the input's island is the working area and the body the committed one: the turn shows over it, what you sent as a bubble on the right and the answer as text on the left: working (a spinner, and the answer it follows while you answer a question), then answered, and the level redraws with what happened. The island starts at a line each and grows away from the screen's edge, never shrinking within the visit, and the prompt says what `RET` does next ("Reply...", nothing while it works). While you stay on the level, the next send continues the conversation, as typed; leaving or closing ends it. An answer the island cannot hold (past three lines, a table, options that do not fit, an approval) opens the whole conversation in Ask by itself, and `ESC` there comes back; `TAB` to the turn and `RET`, or a click, opens it too, and `y` copies its answer. Options a digit picks while the input is empty; a letter first types, digits too. A failure shows in alert, what you sent faded and given back for `RET` to retry. `C-S-RET` leaves the answer to a notification. An input writes, never filters; put an agent's only on a level showing what it changes:

```nix
{
  key = "c"; desc = "Calendar"; status = "clock"; view = "calendar";
  input = {
    desc = "Add an event"; plugin = "assistant"; after = "calendar-sync";
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

Volume steps by `audio.step` up to `audio.max`. The backlight steps by `brightness.step` through logind; set `brightness.set` for another tool. Music reads song and artist out of the XML some radio streams (Bauer Media) send as their title, since MPRIS leaves no glue to do it in.

A level lists up to nine items on fixed digits. `/` filters its list in place, as in a pager or a browser, unless the level binds `/` itself, the legend saying how many rows show at rest of all the list holds while it holds more (`/ 1-9 of 14`); `pick` does it on any other key, its row saying the same: the filter takes the level's island and keeps the items whose label holds every word typed, hidden ones too, in the rows' place, as many at a time as the level showed (nine on a level of their own), so nothing moves. Digits pick from the rows shown, following them, and never type; `↑↓` move the cursor, `RET` runs its item as its digit would and `M-RET` opens its own menu, the filter's range on its right (`2-10 of 14`). `ESC` clears the filter, then closes it, or a level of its own with it. A level's other pickers take any free key (`.` or a letter), their labels ending in `...`. An empty list says why: off, or nothing found.
