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
- `read`: a command whose last line is the state, run as the menu opens and every `every` seconds while it stays open. `qs -c quick-key ipc call <name> refresh` runs it now.

## The state line

A line is a plain value (`true`, `45`, `/walls/sunset.jpg`) or a JSON object, an empty one clearing the state. An object's fields, each optional:

- `value`: what `show` and `items` look up; a plain line is its value.
- `glyph`, `text`, `detail`, `active`, `tone`: the look, over what `show` gives the value.
- `phase` and `kind`: its work, as Rex's [Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status) names it. `idle`; `working`, a spinner; `blocked` on you, in warning, with `kind` `permission`, `question` or `auth`; `done`, lit, a result not seen yet; `error`, in alert. A word it does not know is `idle`. A `watch` that ends takes `working` and `blocked` with it and leaves `done` and `error` to be seen.
- `enabled`: the ids of `items` that can be picked; unset, all.
- `items`: items that change, when the settings list none, each `{ id, label, icon, glyphs, detail, active, enabled, done, hidden, busy, tone, verb, closes, actions }`:
  - `done` dims it, struck through; it can still be picked.
  - `hidden` leaves the rows; filtering (`/`) finds it.
  - `tone` (`warning`) marks one that needs attention, with `glyphs` before its detail so colour is not all that says so.
  - `busy` shows a spinner for its icon while it is being made.
  - `verb` names what choosing it does in the picker's legend (`tick`), and `closes` hides the menu first.
  - `actions`, `[{ key, desc, icon, closes }]`, are its own menu (`M-` and its digit, `M-RET` while filtering), each running `run` with the item's id and the action's key.
- `empty`: why `items` is empty, shown in its place (`No devices paired`).

A line that is not a JSON object is logged and skipped. The shell ignores fields it does not know, and a plugin may read its own (`recording`'s `since`).

## Shipped

List one by name to use it: `plugins.niriMinimap = { };`.

- **`command`:** the state its source gives, as above, under any name.
- **`dunst`:** do-not-disturb for those who keep dunst as their notification daemon; it is not for use with the `notifications` plugin. A bell, struck and lit while dunst is paused; a click pauses or resumes it. Needs `dunstctl` and `dbus-monitor` on `PATH` (with Nix, add dunst to `extraPackages`).
- **`wallpaper`:** the wallpaper's name, from a source whose value is its path.
- **`recording`:** a pill on every screen while recording, and the elapsed time as a status. Its source gives `{"active": true, "since": <epoch seconds>}` while recording.
- **`dictation`:** a pill while dictating, a spinner while transcribing. Its source gives `recording`, `transcribing` or anything else for idle, as its value or as the `stage` its `show` gives (`show.streaming.stage = "recording"`).
- **`niriMinimap`:** a minimap of niri's workspaces as you move between them.
- **`tasks`:** tasks to tick off, from a tasks file (see [Tasks](tasks.md)).
- **`ask`:** a panel for quick turns with an agent, below.
- **`notifications`:** a notification server in the shell's look, below.

## Ask

A panel to ask an agent something without leaving what you are doing. It opens where the menu does, in the same frame, and opening either closes the other. Its prompt sits under the conversation with the keys, and names who it asks until a turn says what `RET` does next. Its keys sit in the bar beside the top level's statuses. Links in an answer show as rows. An answer that comes while the panel is hidden arrives as a notification, unless the menu shows it above the input that sent it.

`ask` is the agent: a command speaking [ACP](https://agentclientprotocol.com) on its stdio. It starts with the first turn and stays for the next, so a turn skips its start and its session's loading. After `idle` minutes without a turn it stops, and the next turn starts it again.

The answer streams in as Markdown, ACP's text format and the one text the shell renders rich. The conversation renders it, fetching nothing and running no HTML: an image shows as its alt text. The menu's island shows it plain. A closing numbered list is the options a digit picks, read from the Markdown's structure, never guessed from plain text.

```nix
# Claude, through Zed's ACP adapter; `open` resumes its session in a terminal.
plugins.ask = { title = "Claude"; ask = "claude-agent-acp"; open = "foot claude --resume"; };

# An agent on another machine, its stdio over SSH; a sync after any tool that writes the agenda.
plugins.ask = { ask = "ssh host hermes-acp"; cwd = "/srv/agent"; toolMatch = "^mcp__agenda__(?!list_)"; toolRun = "calendar-sync"; };
```

A turn resumes the session, or starts one and says so when the old one is gone. Approvals are the agent's permission requests. Stopping cancels the turn, and an agent still answering two seconds later is stopped. A failure ends the turn in alert, saying why ("Sign in to … first", the agent's own error), and the agent's stderr goes to the journal.

| Tested with | Version |
|---|---|
| ACP | protocol v1 |
| Hermes Agent (`hermes-acp`) | 0.22.7 |

Other ACP agents (Claude through `claude-agent-acp`, Codex through `codex-acp`, Gemini CLI, OpenCode, Goose) speak the same protocol and are untested here.

Keys:

- `RET` sends. `C-S-RET` sends and hides the panel, the answer arriving as a notification. `S-RET` breaks the line, and `C-v` attaches the clipboard's image.
- `ESC` clears the prompt, then steps back: to the menu that opened the panel, else hiding it, as a click beside it does. The conversation is kept.
- `C-c` stops the run, refusing what it waits to be allowed. Leaving never stops it.
- `C-y` allows an approval once, which stays in the conversation as a dim line. `C-l` starts a new conversation, `C-o` moves it to a terminal, and `C-r` lists past conversations.
- `TAB` moves the keys between the prompt and the panel. With the prompt dim, plain `l`, `o` and `r` do the same, `y` copies the last answer, and `?` lists every key. Allowing takes `C-y` only, so `y` never approves.

Past conversations are the agent's own (ACP's `session/list`, in `cwd`), in its order, each with its last activity, filtered in the menu as a shell's reverse search is. `RET` resumes one, its history replayed (`session/load`), and its own menu (`M-RET`) has `o`, which opens it in a terminal. An agent that cannot load them dims them, and one that cannot list them says so. An input that gives Ask its text takes `C-r` too.

Its status shows its glyph only while it has something to report: a run, an unread answer, a question for you. To ask from a key, bind `menu press Tab`: the menu opens with its input focused. Two agents are two plugins with `type = "ask"`, and a level's `input` may hand one its text (see [Input](menu.md#input)).

## Notifications

A notification server in the shell's look, in place of dunst or mako. Quickshell speaks the protocol; the plugin decides what shows, for how long, and where. Only one daemon can hold the bus, so turn off `services.dunst` or `services.mako` (the module requires it) and remove their packages: D-Bus starts any daemon whose service file it finds, which can take the bus before the shell does. Another daemon holding it shows as the plugin's error.

The plugin's status is a bell with the count, struck and lit while paused, and a click on it summons the cards. Put it in a slot of the bar, such as `menu.header.right`: `{ key = "n"; desc = "Notifications"; status = "notifications"; }`. Setting a slot replaces the starter's entries there, so keep them from `menu.json`'s `right`; with Nix, `(builtins.fromJSON (builtins.readFile "${config.programs.quick-key.package}/share/quick-key/menu.json")).menu.header.right` is that list.

Cards stack in a corner of the focused screen, newest by the corner, critical ones first. A card shows:

- its app's icon, the summary in bold, and the app on its right, with when it came once it has waited a minute;
- the body in two lines, as plain text: the server tells senders it takes no markup;
- progress (`value`) as a meter, and a picture (album art, a screenshot) on its right;
- its sender's actions below.

A click opens a card, running its default action, else dismissing it. `✕` or a right click dismisses it.

A card shows for its sender's time, else its urgency's `timeout`; a critical one stays until dismissed. Time stops while the pointer is on any card, which also holds the stack still, and after `idle` seconds without input; it starts again in full. One sent again, by its id or its stack tag (`x-dunst-stack-tag`, as volume tools send), replaces its card in its place, its rules and its time starting again. One re-sent by its id with nothing changed restarts nothing: Quickshell tells the shell only of changes.

`limit` cards show at once, `+N` counting the rest. While paused, or while a fullscreen window has focus, cards wait, and their time starts once they show; a critical one shows anyway. A struck bell by the corner counts those waiting, except over a fullscreen window. Past `keep` notifications, the oldest close. Pause survives a reload and a restart; the cards do not survive a restart (a deploy), as the sender still has them.

```nix
plugins.notifications = {
  corner = "top-right";
  rules = [
    { match = { app = "^niri$"; summary = "Screenshot captured"; }; hide = true; }
    { match.app = "^Alfredo$"; timeout = 0; ignorePause = true; }
    { match.body = "(?<code>\\b\\d{6}\\b)"; actions = [ { key = "c"; desc = "Copy {code}"; cmd = ''wl-copy "$NOTIFICATION_CODE"''; } ]; }
  ];
};
```

### Rules

Rules apply in order, later ones winning. A rule applies when each regular expression in its `match` is found in its field: `app`, `summary`, `body`, `category`, `urgency` or `desktopEntry`. Anchor one with `^…$`. They are JavaScript's, with no inline flags: `[Ss]lack` matches either case. A rule with no `match` applies to all, so `{ run = "env | grep ^NOTIFICATION_ >> /tmp/notifications"; }` logs what each tool sends. A rule can set:

- `hide`: drops it, as it arrives or once a replacement matches. No card shows, `C-r` has nothing to bring back, and no `run` runs.
- `timeout`: the seconds it shows; 0, never.
- `urgency` (`low`, `normal`, `critical`): how it shows and lasts.
- `ignorePause`: shows it while paused; a fullscreen window still holds it, as only a critical one shows over one.
- `actions`: its own, each `{ key, desc, cmd, closes }`, `key` a lowercase letter you choose, any but `x`. They come after its reply and before its sender's, whose letters come from their labels. Actions of every matching rule add up, one on a letter an earlier rule took replacing it. Running one dismisses its card; `closes = false` keeps it.
- `default`: what opening it runs, in place of its sender's.
- `run`: a command run as it arrives, not when it is replaced or kept over a reload.

A command gets the notification in its environment, never in its text, as dunst's scripts get `DUNST_*`: `NOTIFICATION_APP`, `NOTIFICATION_SUMMARY`, `NOTIFICATION_BODY`, `NOTIFICATION_URGENCY`, `NOTIFICATION_ID` and `NOTIFICATION_ICON` (a file's path, as a screenshot or album art comes, else an icon name). Each named group of its `match` comes too, upper-cased (`(?<code>\d{6})` as `NOTIFICATION_CODE`), and a `desc` shows it by name (`{code}`). Commands run on the service's `PATH`, so with Nix what they call goes in `programs.quick-key.extraPackages`. The rules are checked as the configuration builds.

There is no sound, per-output placement or per-rule colour.

### Keys

Cards never take the keys on their own, so a notification never takes your typing. `summon` gives them the keys where they are, the newest picked, until you let go. Bind it to a compositor key; in niri's config:

```kdl
binds {
    Mod+N { spawn "qs" "-c" "quick-key" "ipc" "call" "notifications" "action" "summon"; }
}
```

With Nix, the same through `exec.ipc`: `Mod+N { spawn-sh "${config.programs.quick-key.exec.ipc} notifications action summon"; }`.

The plugin's `shortcut` only labels that key. Their keys show where they act, and nothing moves. Summoned, waiting cards show too, `limit` at a time, the arrows scrolling past them. The bar under the cards holds the keys the state changes and counts the cards not shown (`+2`). `?` lists the rest.

- A digit picks a card by its place among all, so it holds still, scrolling it into view. `↑↓` move the pick, scrolling past the last one.
- The picked card's letters run its actions. The keys stay, so one summon can clear several.
- `RET` opens it and lets go. `x` dismisses it, the pick moving on.
- `C-X` clears all. `C-r` brings back the last closed, of the 20 kept, unless its sender marked it transient. `C-p` pauses or resumes.
- `ESC`, or a click beside the cards, lets go.

A key path runs as typing it would: `notifications press "2 x"`. The plugin's actions, for a binding (`notifications action <name>`) or an entry, are `summon`, `invoke` (opens the newest card), `dismiss` (the newest), `clear`, `restore` and `pause`.

### Replies

A sender that takes a reply (the protocol's `inline-reply` action) gets one first among its card's actions, on `TAB`. The prompt takes the actions' place, one line that scrolls, so the card keeps its height, and holds the keys until you leave it:

- `RET` sends it. The reply closes the card and lets go, unless its sender keeps it (`resident`): then the keys stay.
- `C-S-RET` sends it and lets go.
- `ESC` clears it; empty, `ESC` goes back to the card's keys.
- A card keeps its own unsent reply until it goes, and its time holds while it has one.
- A card that closes while you type ends the reply, your text going to the clipboard, so none is lost. The bar says so, and the keys do nothing until `ESC`, so the rest of what you type goes nowhere.

## Writing one in QML

A plugin that needs behaviour (a timer, a surface, a protocol) is a folder, found in `$XDG_CONFIG_HOME/quick-key/plugins/` and then among the shipped ones. `type` names it, by default the plugin's own name, or gives a path to its file.

- `<Name>.qml`, rooted at `Plugin`: its state and actions. It never draws.
- `Settings.qml`, rooted at `PluginSettings`: every setting it takes, with its default and a one-line comment, which is its entry in the reference. It is read as the configuration builds, so it must stay declarative; the shell creates it once to check the config and once to run the plugin.
- One file per view it draws, listed in `views` (`["Minimap.qml"]`). Each is given the plugin as `plugin` and only reads it.

What it gets:

- `name`, `settings` (its part of the config), and `state` (the state line, with `show` and `items` applied).
- `exec(setting, ...args)` runs a command setting, its arguments as `$1`, `$2`. `call(setting, args, then)` runs one and always answers `then(code, output)` once done (127 when unset), so a second call never drops one still running; one that exits non-zero is logged with its last line on stderr. `commandLine(setting, ...args)` builds one for a `Process`.
- The theme (`Config.theme`), the [kit](kit.md), and the services: `Audio`, `Network`, `Bluez`, `Power`, `Brightness`, `Music`, `Tray`, `Compositor`, `Niri` for niri's own events, and:
  - `Picker`: `pick(list)` shows a list by name, filtered, on a menu level of its own over the plugin's panel, which Escape shows again.
  - `Panels`, the stack of surfaces: `open(owner)` shows a plugin's panel on top, `back()` closes it to show what it covered, and `close()` hides them all.

What it gives:

- `glyph`, `text`, `detail`, `glyphs` (before the detail, in its tone), `active` and `tone`, shown wherever its name is a `status`, and `fields` by name for an entry's `format`.
- `fieldTones`: a tone per field, kept when a `format` shows it (`{ updated: "warning" }` on an old sync).
- `error`: why its source or its last action failed, by default its state's own `error`. A level listing it shows it beside its keys, in `alert`.
- `activate()` for a click on it in a bar, and `refresh()`, called as the menu opens.
- `items`, `select(id)` and `run(id, key)` (an action from an item's own menu) for an entry whose `list` is its name. An item may bring a `meter` (0 to 1).
- `actions`: actions by name, as the built-in ones (`{ icon, detail, available, run }`), which an entry of a level listing it names in its `action` (the tasks' `sort`).
- `words`: what only it says (its empty list, its failures). The words the surfaces share are `Words`'s, which a plugin never adds to.
- `submit(text, background, after)` for an input's text when it sets no `cmd`, running `after` once done. It answers false when it does not take the text, which the input then keeps. `busy` while it takes no text shows a spinner in the input; a plugin sets its `phase` to working or blocked rather than `busy`.
- `watched` while the menu shows an input giving it text, set as a visit starts, and `visitEnded` (through `endVisit()`) as it ends: the input or its plugin changes, or the menu closes.
- `turn`, the conversation's turn as the menu draws it while watched, null before the first: `{ question, context, text, phase, kind, activity, options, table, steps }`. `phase` and `kind` are a state line's: `working` (with `activity`, and `context` the answer it follows), `done`, `blocked` on a `question` (`options` a digit picks) or for `permission`, `error` (the input getting the text back), or `idle` once stopped. `steps` are what you answered on the way (an approval).
- `recall()` to show its past conversations filtered in the menu, for `C-r` in an input giving it text, while `recalls`: the picker opens over what asked for it.
- `expand()` to show the conversation in its own panel over the menu, when the answer over the input cannot fit it; stepping back shows the menu again where it was, the visit going on. It answers false without a panel.
- `empty`: why its list is empty, shown in its place; by default its state's own `empty`.
- `shortcut`, its compositor key.

Every plugin answers `<name> activate`, `<name> refresh` and `<name> action <action>` over IPC, the last running one of its `actions` as an entry naming it would.
