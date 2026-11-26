# Menu

The menu is a list of levels, each drawn in the body. Beside it sit an optional bar and input, on islands stacked up from the screen's edge.

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
- The islands on screen hold one key map, no key on two of them, and a key goes to the island that shows it wherever the cursor is: under `[ "input" { level = "t"; } "body" "bar" ]`, `2` ticks the second task and `a` opens Audio output as the menu opens. The check refuses two things on one key on one screen: two lists (pinned, or one pinned on a level that lists), a pinned level's letter on one of the body's or its row on a bar key with Ctrl, a key the view takes on a row or a pinned level.
- One island has the cursor: the body, or a pinned level once its key (on the level that pins it) or a click gives it the cursor. Its arrows, `RET` and `M-RET` act there, and the input is its own; the others show no cursor. `/` filters a pinned list and gives it the cursor, as the filter is typed in the input. The bar is that island's, as the input is: its actions and legend, then its level's slots, so a pinned level's bar is its keys alone; `?` lists every key on screen. What a pinned level opens (an item's own menu, `0`) opens in the body, and stepping back gives it the cursor again.
- `ESC` is the one way back, as in a launcher. It clears what you typed, then leaves an input or the bar for its island, closes the filter or a focused event, gives the cursor back to the body from a pinned level, then returns where you came from (the level above, or the panel or input that opened it), and at the root closes the menu. It never stops or answers anything. `DEL` only deletes. A level opened on its own, by a shortcut or a key path, is a root.
- Digits pick from a level's list; `Alt+digit` opens an item's own menu (a tray app's).
- On a level whose entries leave the arrows free, they move a cursor. On a list, `↑↓` move over the rows shown, the first from the item in use. On a menu's rows, `↓↑` move a row and `←→` one, as laid out, the first onto the first row or the last; each pair moves only where the level binds neither of its keys. The cursor stops at the edges, but `↑↓` past an island's first or last row move it onto the nearest row of the island above or below, or the bar, where that one leaves the arrow free too: never into an input or a view, and `←→` never cross. `RET` runs its row as its key would, a capital's too (on a pair, nothing, as a click), and `M-RET` an item's own menu. A list's legend names what `RET` does; on a menu's rows `?` does, so the bar holds still. Back on a level, `ESC` finds its row where it was. Digits keep their items, and a key path never moves the cursor.
- The cursor may stand on the bar: `↓` past the last row of the island above it lands on its first stop and `↑` leaves it, the bar staying the bar of the island the cursor came from. Its stops are what a click runs, left to right: the actions on its left but a pair (the volume's, which a click never runs), then each item drawn but a status that only shows, one that cannot run now dimmed. `←→` move across them where no row on screen takes them (on Audio output they stay the volume's), `RET` runs the item as a click does and `M-RET` opens its own menu (a tray app's); `ESC` back from what it opened lands on it again. Digits, letters and `Ctrl` keep their targets. A click on an item gives it the cursor too.
- `Ctrl` reaches the body's level's bar wherever the keys are, on a pinned level too, and in an input or a filter where its text leaves the key: what the bar draws follows the cursor, its keys never. A bar entry with `key = "c"` runs on `C-c`, a list in it on `C-1` to `C-9`, and `C-M-1` opens an item's own menu there. Holding `Ctrl` for a second lists the bar's keys in place of the body, as icons alone cannot say what they run.
- Two keys with a command or action each (`[ "Left" "Right" ]`) share a row, named for what it changes (`Volume`, `Track`). The first steps down or back: `←→` is less then more or back then forward, `↓↑` less then more, and `↑↓` back then forward, up going back in time as on a scrolled page. Held, a pair repeats on its level, never into the level it opens; a letter or digit acts once.
- Device levels put Power on `p` and Configure... on `c`, and what ends the session takes Shift on its own key (Reboot, Shutdown).
- `Ctrl` and `Alt` may prefix a key in the body (`Ctrl+Left`, as niri writes bindings) where its bar does not take it. A modifier never runs the plain key, Shift only picks the capital letter, and Super stays the compositor's.
- Hints show keys Emacs-style: `C-` Ctrl, `M-` Alt, `s-` Super, Shift as the capital letter, symbols for the arrows, `DEL` for Backspace and `ESC` for Escape (`C-←→`, `s-k`).
- Holding `Super` for a second lists each bar entry's `shortcut`, the compositor key bound to it.
- `?` lists the keys no row of any island shows, where they act: each hold while it lists something, each pinned level's key, the arrows where they move a cursor, `RET` on a menu's rows, `M-1` while an item has its own menu, `ESC` and, where an input shows, `TAB` and `C-S-RET`. Any key closes it. Every bar but the filter's shows `? keys`, as every surface with such a list shows its key there; `menu.keysHint` off leaves these out, the keys still acting. A level's `legend` names those of its keys to show in its bar too (`[ "Ctrl+Up" ]`), as which matter is yours to say.
- `menu toggleEntry <key>` over IPC opens a top-level entry, in the body or the bar, for a compositor shortcut; a pinned level it gives the cursor, closing the menu if it has it.
- `keepAwake toggle` over IPC switches keep awake without the menu, and `keepAwake enable` turns it on, for a script.
- `menu press "<path>"` runs a key path as typing it would (`"a 2"`, `"Ctrl+x"`, keys named as entries declare them), from the top level at rest whatever the open menu shows, so a binding reaches anything the menu does. A key that closes the menu ends the path. A path that opened the menu closes it after the action it ends on, unless that entry sets `keepOpen = true`. A digit is the same item only while it is in `pins`. A path runs the same through a pinned level (`t 2`), and its keys need no path through it (`2`). `menu keys` prints every path as Markdown.

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

A level's body fits what it shows, unless its entry's `height`, else `menu.height`, gives it at least that many rows (`height = 5`): as tall as five of its rows, its far side left blank, and taller only for more. A body that fits moves what lies farther from the edge as levels change; a height holds it still. A view fits, and a pinned level fits its rows.

The menu sits at the bottom of the screen, centred. `menu.layout` lists its islands top to bottom, the last against the edge: by default the input, the body, then the bar (`[ "input" "body" "bar" ]`). `[ "body" "input" "bar" ]` puts the input between the body and the bar. An island with nothing to show (a level without an input, a bar without content) shows empty and holds its place; only islands at the far end may stay out, since nothing lies beyond them. Every layout has the body, once; leave out `input` and no level has an input or a filter (a picker still lists, its arrows moving, with no query to type), leave out `bar` and no level shows its bar, though its keys still act. A plugin's panel sits where the menu does. Nothing else moves: every level keeps the bottom edge.

`{ level = "t"; }` makes the top-level entry on `t` a pinned level, drawn on its island, its row leaving the body: `[ "input" { level = "t"; } "body" "bar" ]` keeps your tasks above the top level's rows. A pinned level belongs to the level that pins it, as its row did: it shows there only, steps aside on every level opened from it, and comes back with `ESC`. It is as wide as its entry's `width`, else `menu.width`, and never shrinks while it shows. A pinned list shows up to its `limit` items on digits (nine unset), past it `0` listing them all in the body. Its `status`, `format`, `bar` and `layout` would show nowhere, so the check refuses them.

An entry's `layout` is its level's, as `menu.layout` is the top's, until `ESC` leaves that level and the layout and island with the cursor before it come back. An entry without one opens in the body of the layout showing. A pinned level in it names a key of that entry's level, so a pin below the top level is declared in its own level's `layout` (`layout = [ "input" { level = "e"; } "body" "bar" ];`).

## Bars

`menu.bar.left`, `center` and `right` are the top level's bar, like waybar's modules. An entry's `bar` is its level's, with the same slots. The bar island shows the bar of the island with the cursor: a pinned level has none of its own, so with the cursor on your tasks the bar holds their keys and legend alone, and the clock and the rest come back with the cursor. It shows empty only while no island the cursor may be on has anything for it, so moving the cursor never adds or removes it. A bar holds content (a song, its modes), never a title. A slot holds entries and, by name, statuses and plugins (a click calls a plugin's `activate`). A crowded bar shortens its text, whole on hover, then shows actions by their glyphs alone, named with their value on hover, the value staying while it warns; it never widens the menu, so one that still cannot fit runs past it, and the log says how wide it needs the menu.

In a bar, an entry shows its status, else its icon, else its `desc`, dimmed, and may do nothing but show its status. With both, it shows its icon in the tone of what its `format` shows, a spinner while the status is busy, and its value on hover, beside it too while that tone warns or where the value is the point (the keyboard layout). So a Sync button stays out of the way until its sync is under way or stale ([Calendar](calendar.md)).

An entry with a `list` shows each item: the tray shows each app's icon, up to its `limit` (nine at most), and past that `+N` on `C-0` shows them all on a level of their own. With a `key` it shows as one entry instead, opening its level (`{ key = "b"; desc = "Bluetooth"; status = "bluetooth"; list = "bluetooth"; }` on `C-b`). Its `hide` leaves out the apps it names by their tray id (`[ "blueman" ]`), for one whose state the bar already shows. An app's own menu has a bar of its own: the app's icon and name, and the submenus opened since (`blueman › Plugins`).

```nix
menu.bar.left = [ { key = "c"; desc = "Calendar"; status = "clock"; view = "calendar"; } ];
menu.bar.right = [ "battery" { desc = "Tray"; list = "tray"; limit = 5; } ];
```

Dates and times are said one way everywhere, in `clock.locale`: a time as the locale writes it (14:30, 2:30 PM), a day as yesterday, today or tomorrow, its weekday within the coming week, else its date (3 Nov), with its year when not this one. Short names are cut to three letters where that still tells them apart (Sep, not Sept). Only dates and times follow it: the shell's own words, today and tomorrow among them, stay English.

## Input

An entry's `input` gives its level a line of text on the input island, a bar entry's and a pinned level's too. `menu.input` gives the top level's, a catch-all for what belongs to no level (`menu.input = { desc = "Ask..."; plugin = "assistant"; }`). The island shows the input of the island with the cursor; with none, its prompt's glyph dimmed.

An input takes letters only while focused, so keys hold still. `TAB` goes to the input of the island with the cursor, then to each other input on screen top to bottom, then back to the rows it left, and `S-TAB` the other way round; a click focuses an input too. `RET` sends and keeps it focused, `C-S-RET` sends and closes the menu, and `ESC` clears it, then gives the cursor to its island. Unsent text stays until sent or cleared, closing the menu too. Focused, its keys show on its right. Empty, it shows its `desc`, which ends in `...`, as what waits on you does.

The text goes to `cmd` as `$1`, else to `plugin`, else to the plugin the level lists (tasks adds it as a task). What a plugin makes of it shows on the input island until done (a task until listed), and the island never shrinks within the visit. The config says where text goes; how the write is done (order, retries, reporting) is the command's, never a new field.

```nix
{ key = "k"; desc = "Tasks"; status = "tasks"; list = "tasks"; input = { desc = "Add a task..."; }; }
```

`context` is what a plugin is told beside each message, on a line of its own; the conversation shows the text as typed. Word it as where the text comes from, not as an order, since a reply to the agent's question carries it too. `after` runs, given nothing, once the write is done: `cmd` exiting 0, a task added, Ask answering. A command reports its own failure (`notify-send`).

Given to [Ask](ask.md), the input's island is the working area and the body the committed one. The turn shows above the prompt: what you sent as a bubble on the right, the answer as text on the left, with a spinner while it works. Then the level redraws with what happened. The island starts at a line each and grows away from the screen's edge, never shrinking within the visit. The prompt says what `RET` does next ("Reply...", nothing while it works). While you stay on the level, the next send continues the conversation, whichever island has the cursor; leaving or closing ends it.

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

While filtering, digits pick from the rows shown and never type. `↑↓` move the cursor, starting where it was at rest, `PgUp` and `PgDn` a page of rows, `RET` runs its item as its digit would, and `M-RET` opens its own menu. The filter's range sits on its right (`2-10 of 14`). `ESC` clears the filter, then closes it, and with it a level opened only to filter; the cursor stays on the row its arrows moved to.

A level's other pickers take any free key (`.` or a letter), their labels ending in `...`.
