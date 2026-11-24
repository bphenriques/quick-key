# Plugins

A plugin adds a status, a list or a surface. List it by name under `plugins`, with its settings beside it. Nothing loads unlisted, and one that fails to load is logged and left out. Every setting is in the [reference](options.md#plugin-settings).

## Without QML

Most plugins need no QML: `type = "command"`, under any name. A source gives a value, and `show` says how each value looks.

```nix
plugins.doNotDisturb = {
  type = "command";
  watch = "dnd-status --follow";             # prints true or false on every change
  activate = "dnd-toggle";                   # a click on it in a bar
  show = {
    "true"  = { glyph = "󰂛"; tone = "alert"; active = true; };
    "false" = { glyph = "󰂚"; };
  };
};
```

For a fixed set of choices, `items` lists them, for an entry whose `list` is the plugin's name. The source's value names the one in use, `select` runs with the chosen `id`, and `run` with an item's `id` and the key of an action from its own menu.

```nix
plugins.displayLayout = {
  type = "command";
  read = "displayctl status";                # {"value": "extend", "enabled": ["laptop", "extend"]}
  select = "displayctl layout";
  items = [
    { id = "laptop"; label = "Laptop only"; icon = "󰌢"; }
    { id = "extend"; label = "Extend"; icon = "󰍺"; }
  ];
};
```

## Sources

A plugin's state comes from one source:

- `watch`: a command that runs for as long as it lasts, each line the new state. It must flush each line (`stdbuf -oL`, `--line-buffered`), and is restarted when it exits.
- `file`: a file holding the state, read on every change.
- `read`: a command whose last line is the state, run as the menu opens, every `every` seconds while it stays open, and once `activate` ends. `qs -c quick-key ipc call <name> refresh` runs it now.

## The state line

A line is a plain value (`true`, `45`, `/walls/sunset.jpg`) or a JSON object, an empty one clearing the state. An object's fields, each optional:

- `value`: what `show` and `items` look up; a plain line is its value.
- `glyph`, `text`, `detail`, `active`, `tone`: the look, over what `show` gives the value.
- `phase` and `kind`: its work, as Rex's [Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status) names it. `idle`; `working`, a spinner; `blocked` on you, in warning, with `kind` `permission`, `question` or `auth`; `done`, lit, a result not seen yet; `error`, in alert. A word it does not know is `idle`. A `watch` that ends takes `working` and `blocked` with it and leaves `done` and `error` to be seen.
- `enabled`: the ids of `items` that can be picked; unset, all.
- `items`: items that change, when the settings list none, each `{ id, label, icon, glyphs, detail, swatch, active, enabled, done, hidden, busy, tone, verb, closes, actions }`:
  - `done` dims it, struck through; it can still be picked.
  - `hidden` leaves the rows; filtering (`/`) finds it.
  - `tone` (`warning`) marks one that needs attention, with `glyphs` before its detail so colour is not all that says so.
  - `busy` shows a spinner for its icon while it is being made.
  - `swatch`, a colour that is data (`#ff8c00`, a task's list), is a dot at the end of its row.
  - `verb` names what choosing it does in the picker's legend (`tick`), and `closes` hides the menu first.
  - `actions`, `[{ key, desc, icon, closes }]`, are its own menu (`M-` and its digit, `M-RET` while filtering), each running `run` with the item's id and the action's key.
- `empty`: why `items` is empty, shown in its place (`No devices paired`).

A line that is not a JSON object is logged and skipped. The shell ignores fields it does not know, and a plugin may read its own (`recording`'s `since`).

## Shipped

List one by name to use it: `plugins.niriMinimap = { };`.

- **`command`:** the state its source gives, as above, under any name.
- **`dunst`:** do-not-disturb for those who keep dunst as their notification daemon; it is not for use with the `notifications` plugin. A bell, struck and lit while dunst is paused; a click pauses or resumes it. Needs `dunstctl` and `dbus-monitor` on `PATH` (with Nix, add dunst to `extraPackages`).
- **`mako`:** the same for mako, through a mode named `do-not-disturb` that your mako config hides notifications in (`[mode=do-not-disturb]` with `invisible=1`). Read as the menu opens, as mako signals no change of mode; bind a key to `mako activate` over IPC, not to `makoctl`, so the bell follows it. Needs `makoctl` on `PATH`.
- **`recording`:** a pill on every screen while recording, and the elapsed time as a status. Its source gives `{"active": true, "since": <epoch seconds>}` while recording.
- **`dictation`:** a pill while dictating, a spinner while transcribing. Its source gives `recording`, `transcribing` or anything else for idle, as its value or as the `stage` its `show` gives (`show.streaming.stage = "recording"`).
- **`niriMinimap`:** a minimap of niri's workspaces as you move between them.
- **`tasks`:** tasks to tick off, from a tasks file (see [Tasks](tasks.md)).
- **`ask`:** a panel for quick turns with an agent (see [Ask](ask.md)).
- **`notifications`** (experimental): a notification server in the shell's look, keyboard first (see [Notifications](notifications.md)).

## Writing one in QML

A plugin that needs behaviour (a timer, a surface, a protocol) is a folder, found in `$XDG_CONFIG_HOME/quick-key/plugins/` and then among the shipped ones. `type` names it, by default the plugin's own name, or gives a path to its file.

- `<Name>.qml`, rooted at `Plugin`: its state and actions. It never draws.
- `Settings.qml`, rooted at `PluginSettings`: every setting it takes, with its default and a one-line comment, which is its entry in the reference. It is read as the configuration builds, so it must stay declarative; the shell creates it once to check the config and once to run the plugin.
- One file per view it draws, listed in `views` (`["Minimap.qml"]`). Each is given the plugin as `plugin` and only reads it.
- A type of its own it uses by name (Ask's `Acp`, the notifications' `Card`), listed in a `qmldir` beside it (`Acp 1.0 Acp.qml`), since the shipped folders resolve no type without one.

What it gets:

- `name`, `settings` (its part of the config), and `state` (the state line, with `show` and `items` applied).
- `exec(setting, ...args)` runs a command setting, its arguments as `$1`, `$2` after its text, which the check fails when it ends in `;`, `&` or `|`. `call(setting, args, then)` runs one and always answers `then(code, output)` once done (127 when unset), so a second call never drops one still running; one that exits non-zero is logged with its last line on stderr. `commandLine(setting, ...args)` builds one for a `Process`.
- The theme (`Config.theme`), the [kit](kit.md), and the services: `Audio`, `Network`, `Bluez`, `Power`, `Brightness`, `Music`, `Tray`, `Compositor`, `Niri` for niri's own events, and:
  - `Picker`: `pick(list)` shows a list by name, filtered, on a menu level of its own over the plugin's panel, which Escape shows again.
  - `Panels`, the stack of surfaces: `open(owner)` shows a plugin's panel on top, `back()` closes it to show what it covered, and `close()` hides them all.

What it gives:

- `glyph`, `text`, `detail`, `glyphs` (before the detail, in its tone), `active` and `tone`, shown wherever its name is a `status`, and `fields` by name for an entry's `format`.
- `fieldTones`: a tone per field, kept when a `format` shows it (`{ updated: "warning" }` on an old sync).
- `error`: why its source or its last action failed, by default its state's own `error`. A level listing it shows it beside its keys, in `alert`.
- `activate()` for a click on it in a bar, and `refresh()`, called as the menu opens.
- `press(path)` for a key path on a surface of its own (`<name> press "2 x"`), run as typing it would; false if it takes none.
- `items`, `select(id)` and `run(id, key)` (an action from an item's own menu) for an entry whose `list` is its name. An item may bring a `meter` (0 to 1).
- `actions`: actions by name, as the built-in ones (`{ icon, detail, available, run }`), which an entry of a level listing it names in its `action` (the tasks' `sort`).
- `words`: what only it says (its empty list, its failures). The words the surfaces share are `Words`'s, which a plugin never adds to.
- `submit(text, after)` for an input's text when it sets no `cmd`, running `after` once done. It answers false when it does not take the text, which the input then keeps. `busy` while it takes no text shows a spinner in the input; a plugin sets its `phase` to working or blocked rather than `busy`.
- `watched` while the menu shows an input giving it text, set as a visit starts, and `visitEnded` (through `endVisit()`) as it ends: the input or its plugin changes, or the menu closes.
- `turn`, the conversation's turn as the menu draws it while watched, null before the first: `{ question, text, phase, kind, activity, table, steps }`. `phase` and `kind` are a state line's: `working` (with `activity`), `done`, `blocked` for `permission`, `error` (the input getting the text back), or `idle` once stopped. `steps` are what you answered on the way (an approval).
- `recall()` to show its past conversations filtered in the menu, for `C-r` in an input giving it text, while `recalls`: the picker opens over what asked for it.
- `expand()` to show the conversation in its own panel over the menu, when the answer over the input cannot fit it; stepping back shows the menu again where it was, the visit going on. It answers false without a panel.
- `empty`: why its list is empty, shown in its place; by default its state's own `empty`.
- `shortcut`, its compositor key.

Every plugin answers `<name> activate`, `<name> refresh` and `<name> action <action>` over IPC, the last running one of its `actions` as an entry naming it would.
