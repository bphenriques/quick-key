# Menu

The menu is a list of levels. Each is a body, with an optional bar between it and the screen's edge.

A body holds one thing. It is either entries, each a key and a label that does something or opens a level, or a level's content: a list, or a view such as the calendar. A content level's own entries and its legend sit on its bar's left, so a list that grows never moves them. When they do not all fit, each shows only its key and glyph, its label as its tip. The bar also holds what you glance at.

```nix
{
  key = "a";
  desc = "Audio output";
  status = "sink";    # on the right of its row: the output in use and its volume
  list = "sinks";     # its level lists the outputs, on digits, each with its volume
  submenu = [         # and its actions, on letters
    { key = [ "Left" "Right" ]; desc = "Volume"; action = "sinkVolume"; }
    { key = "m"; desc = "Mute"; action = "sinkMute"; }
    { key = "c"; desc = "Configure..."; icon = "󰘮"; cmd = "pavucontrol"; }
  ];
}
```

## Keys

Letters are actions and digits are list items.

- A letter runs its entry or opens its level.
- `ESC` is the one way back, as in a launcher. It clears what you typed, then leaves an input for its level's body, closes the filter or a focused event, then returns where you came from (the level above, or the panel or input that opened it), and at the root closes the menu. It never stops or answers anything. `DEL` only deletes. A level opened on its own, by a shortcut or a key path, is a root.
- Digits pick from a level's list; `Alt+digit` opens an item's own menu (a tray app's).
- On a level whose entries leave the arrows free, they move a cursor. On a list, `↑↓` move over the rows shown, the first from the item in use. On a menu's rows, `↓↑` move a row and `←→` one, as laid out, the first onto the first row or the last; each pair moves only where the level binds neither of its keys. The cursor stops at the edges. `RET` runs its row as its key would (on a pair, nothing, as a click), `S-RET` a row whose key takes Shift, and `M-RET` an item's own menu. Back on a level, `ESC` finds its row where it was. Digits keep their items, and a key path never moves the cursor.
- `Ctrl` reaches the bar: a bar entry with `key = "c"` runs on `C-c`, a list in it on `C-1` to `C-9`, and `C-M-1` opens an item's own menu there. Holding `Ctrl` for a second lists the bar's keys in place of the body, as icons alone cannot say what they run.
- Two keys with a command or action each (`[ "Left" "Right" ]`) share a row, named for what it changes (`Volume`, `Track`). The first steps down or back: `←→` is less then more or back then forward, `↓↑` less then more, and `↑↓` back then forward, up going back in time as on a scrolled page. Held, a pair repeats on its level, never into the level it opens; a letter or digit acts once.
- Device levels put Power on `p` and Configure... on `c`, and what ends the session takes Shift (Reboot, Shutdown).
- `Ctrl` and `Alt` may prefix a key in the body (`Ctrl+Left`, as niri writes bindings) where its bar does not take it. A modifier never runs the plain key, Shift only picks the capital letter (and makes `RET` `S-RET`), and Super stays the compositor's.
- Hints show keys Emacs-style: `C-` Ctrl, `M-` Alt, `s-` Super, Shift as the capital letter, symbols for the arrows, `DEL` for Backspace and `ESC` for Escape (`C-←→`, `s-k`).
- Holding `Super` for a second lists each bar entry's `shortcut`, the compositor key bound to it.
- `?` lists the keys no row shows, where they act: each hold while it lists something, the arrows where they move a cursor, `M-1` while an item has its own menu, `ESC` and, on a level with an input, `TAB` and `C-S-RET`. Any key closes it. The top level's bar shows `? keys`, as every surface with such a list shows its key there; `menu.keysHint` off leaves these out, the keys still acting. A level's `legend` names those of its keys to show in its bar too (`[ "Ctrl+Up" ]`), as which matter is yours to say.
- `menu toggleEntry <key>` over IPC opens a top-level entry, in the body or the bar, for a compositor shortcut.
- `keepAwake toggle` over IPC switches keep awake without the menu, and `keepAwake enable` turns it on, for a script.
- `menu press "<path>"` runs a key path from the top level as typing it would (`"a 2"`, `"Ctrl+x"`, keys named as entries declare them), so a binding reaches anything the menu does. A key that closes the menu ends the path. A path that opened the menu closes it after the action it ends on, unless that entry sets `keepOpen = true`. A digit is the same item only while pinned. `menu keys` prints every path as Markdown.

## What an entry does

One of:

- `cmd`: a shell command. The menu closes, unless `keepOpen = true`.
- `action`: a built-in action (below), or one of the plugin its level lists (the tasks' `sort`). It brings its icon, which shows its state (Wi-Fi off), and what lights it, keeps the menu open, and dims while it has nothing to act on (no player, no adapter). What can never run on this machine is not declared.
- `submenu`, `list` or `view`: a level. `list` adds items found at runtime on digits. `pins` keeps chosen ones on their digit, dim while absent, their label naming them wherever the menu shows them; the rest follow by name, internal audio first, never by signal or recency. `view = "calendar"` shows the [calendar](calendar.md).

The label is `desc`, and never changes. The icon is `icon`, or its `status`'s or `action`'s own; the starter gives every row one.

`status` shows live state on the right of the row, or beside the label for an action in its level (Brightness 55%). A status names its state in words only when it has no value to show, in lowercase but for a name (`off`, `muted`, `Wi-Fi off`), and never for a state its icon or tone already shows. A level's state sits on the row that changes it: power in Power's icon.

`format` picks a status's fields (`"{song}"`), and what follows a `|` stays whole on the right (`"{title}|{when}"`). A built-in status has a format of its own (the volume's is `"{device}|{volume}"`), which an entry's replaces.

`activeWhen` lights an entry of your own. A bar entry showing a plugin's status with no `cmd` or `action` activates the plugin, on a click or its key.

A level is as wide as its entry's `width`, else `menu.width`, and lays its actions out in its entry's `columns`, else `menu.columns` (`columns = 1` for a level of three, so none sits alone). Neither is measured from what it shows, so it holds still. Entries flow across, so order decides neighbours. At the top the columns are equal, so values line up; in a level the last hugs its rows against the right edge. It is never wider than the screen, whatever it asks; short of room, text shortens, short values last and icons never. Make the menu wider before adding columns or truncating.

The menu sits at the bottom of the screen, centred, its bar against the edge. Everything stacks up from there: the bar, the body, then the level's input. A plugin's panel sits where the menu does. Nothing else moves: the bar never sits apart from the body, and every level keeps the bottom edge.

## Bars

`menu.header.left`, `center` and `right` are the top level's bar, like waybar's modules. An entry's `header` is its level's, with the same slots, and a level with nothing for its bar is its body alone. A bar holds content (a song, its modes), never a title. A slot holds entries and, by name, statuses and plugins (a click calls a plugin's `activate`). A crowded bar shortens its text, whole on hover, then shows actions by their glyphs alone; it never widens the menu, so one that still cannot fit runs past it, and the log says how wide it needs the menu.

In a bar, an entry shows its status, else its icon, else its `desc`, dimmed, and may do nothing but show its status. With both, it shows its icon in the tone of what its `format` shows, a spinner while the status is busy, and its value on hover, beside it too while that tone warns or where the value is the point (the keyboard layout). So a Sync button stays out of the way until its sync is under way or stale ([Calendar](calendar.md)).

An entry with a `list` shows each item: the tray shows each app's icon, up to its `limit` (nine at most), and past that `+N` on `C-0` shows them all on a level of their own. An app's own menu has a bar of its own: the app's icon and name, and the submenus opened since (`blueman › Plugins`).

```nix
menu.header.left = [ { key = "c"; desc = "Calendar"; status = "clock"; view = "calendar"; } ];
menu.header.right = [ "battery" { desc = "Tray"; list = "tray"; limit = 5; } ];
```

Dates and times are said one way everywhere, in `clock.locale`: a time as the locale writes it (14:30, 2:30 PM), a day as yesterday, today or tomorrow, its weekday within the coming week, else its date (3 Nov), with its year when not this one. Short names are cut to three letters where that still tells them apart (Sep, not Sept). Only dates and times follow it: the shell's own words, today and tomorrow among them, stay English.

## Input

An entry's `input` floats a line of text over its level's body, a bar entry's too. `menu.input` does over the top level's, a catch-all for what belongs to no level (`menu.input = { desc = "Ask..."; plugin = "assistant"; }`).

An input takes letters only while focused, so keys hold still. `TAB` moves the keys from the body to the input on every level, and `TAB` or `S-TAB` back; a click focuses it too. `RET` sends and keeps it focused, `C-S-RET` sends and closes the menu, and `ESC` clears it, then gives the keys back to the body, as `TAB` does. Unsent text stays until sent or cleared, closing the menu too. Focused, its keys show on its right. Empty, it shows its `desc`, which ends in `...`, as what waits on you does.

The text goes to `cmd` as `$1`, else to `plugin`, else to the plugin the level lists (tasks adds it as a task). What a plugin makes of it shows over the body until done (a task until listed), and the island never shrinks within the visit. The config says where text goes; how the write is done (order, retries, reporting) is the command's, never a new field.

```nix
{ key = "k"; desc = "Tasks"; status = "tasks"; list = "tasks"; input = { desc = "Add a task..."; }; }
```

`context` is what a plugin is told beside each message, on a line of its own; the conversation shows the text as typed. Word it as where the text comes from, not as an order, since a reply to the agent's question carries it too. `after` runs, given nothing, once the write is done: `cmd` exiting 0, a task added, Ask answering. A command reports its own failure (`notify-send`).

Given to [Ask](ask.md), the input's island is the working area and the body the committed one. The turn shows over the body: what you sent as a bubble on the right, the answer as text on the left, with a spinner while it works. Then the level redraws with what happened. The island starts at a line each and grows away from the screen's edge, never shrinking within the visit. The prompt says what `RET` does next ("Reply...", nothing while it works). While you stay on the level, the next send continues the conversation; leaving or closing ends it.

An answer the island cannot hold (past three lines, a table, an approval) opens the whole conversation in Ask, and `ESC` there comes back. A click on the turn opens it too, where `C-C` copies the answer. A failure shows in alert, what you sent faded and given back, selected: `RET` retries it, typing replaces it. `C-S-RET` leaves the answer to a notification.

An input writes, never filters. Put an agent's input only on a level showing what it changes:

```nix
{
  key = "c"; desc = "Calendar"; status = "clock"; view = "calendar";
  input = {
    desc = "Add an event..."; plugin = "assistant"; after = "calendar-sync";
    context = "From the menu's Calendar input: an event to add, or an answer to your question";
  };
}
```

## Mouse

The mouse reaches what the keys do. A click runs a row or a bar item. A right click opens a tray app's menu or, beside the rows, goes back a level. The wheel steps a pair (volume, brightness), up as its second key, or the calendar's month. Over a row that opens a level, it steps the pair its status adjusts (Audio output's volume); a command pair there steps only on its own row. Resting on an icon in a bar names it.

## Built-in names

Each of `status`, `list`, `action` and `activeWhen` takes a built-in name or a plugin's, and `view` a built-in. The reference lists them, generated from the shell: [statuses](options.md#statuses) and their fields, [actions](options.md#actions), [lists](options.md#lists), [states](options.md#states) for `activeWhen`, and [views](options.md#views). A plugin's status gives `format` its `text`, `detail` and fields of its own.

A digit on `streams` picks the app `streamVolume` and `streamMute` change, the first until you pick; the starter gives them Left and Right.

The wheel over a device or an app changes its own volume. Where `audio.max` allows past 100%, a volume's meter is full at `audio.max`, and a step up never lowers a volume set past it elsewhere.

The Wi-Fi list scans for networks while it is open, and a network or device shows a spinner as it connects or disconnects. The network's glyph follows the signal. Behind a captive portal or with no internet it warns, `internet` saying so. The `wifi` action dims while a hardware switch blocks the radio.

Music follows `music.player`, else the player playing, else the last that played. A stream that packs song and artist into its title (some radios send an XML document) is split by `music.titleMatch`, since MPRIS leaves no glue to do it in.

Power profiles (power saver, balanced, performance where the machine has it) are offered only where their daemon, power-profiles-daemon or tuned-ppd, is on the system bus, which `daemons.list` reads as the menu opens. Without it the action dims, the list says so and the status shows nothing.

A level lists up to nine items on fixed digits. While the list holds more than the rows show, the legend says how many (`/ 1-9 of 14`). An empty list says why: off, or nothing found.

`/` filters the list in place, as in a pager or a browser, unless the level binds `/` itself. The filter takes the level's input and keeps the items whose label holds every word typed, case and accents aside (`cafe` finds `Café`), hidden ones too. They show in the rows' place, as many as the level showed, so nothing moves.

While filtering, digits pick from the rows shown and never type. `↑↓` move the cursor, starting where it was at rest, `PgUp` and `PgDn` a page of rows, `RET` runs its item as its digit would, and `M-RET` opens its own menu. The filter's range sits on its right (`2-10 of 14`). `ESC` clears the filter, then closes it, and with it a level opened only to filter.

A level's other pickers take any free key (`.` or a letter), their labels ending in `...`.
