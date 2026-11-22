# Plugins

A plugin adds a status, a list or a surface. List it by name under `plugins`, with its settings beside it. Nothing loads unlisted, and one that fails to load is logged and left out. What needs more of one tool is a plugin.

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

For dunst, the shipped `dunst` plugin is this, ready to list: `plugins.dunst = { };`.

The source is one of:

- `watch`: a command that runs for as long as it lasts, each line the new state. It must flush each line (`stdbuf -oL`, `--line-buffered`), and is restarted when it exits.
- `file`: a file holding the state, read on every change. A relative path is under `$XDG_RUNTIME_DIR`.
- `read`: a command whose last line is the state, run as the menu opens. `every` (seconds) runs it again while the menu stays open. `qs -c quick-key ipc call <name> refresh` runs it now.

`show` maps each value to `{ glyph, text, detail, active, tone }`; a value without one shows as text.

`title` names it in tips, prompts and notifications; unset, its name in `plugins`. `glyph` is its glyph when its state names none. `activate` is what a click on it in a bar, or `<name> activate` over IPC, runs.

For a fixed set of choices, `items` lists them, each `{ id, label, icon, detail }`, for an entry whose `list` is the plugin's name. The source's value names the one in use, and `select` runs with the chosen `id`; `run` runs with an item's `id` and the key of the action chosen from its own menu.

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

## The state line

A line is a plain value (`true`, `45`, `/walls/sunset.jpg`) or a JSON object, an empty one clearing the state. An object's fields, each optional:

- `value`: what `show` and `items` look up; a plain line is its value.
- `glyph`, `text`, `detail`, `active`, `tone`: the look, over what `show` gives the value.
- `phase` and `kind`: its work, as Rex's [Program Status Protocol](https://www.superlogical.com/rex/docs/build/program-status) names it: `idle`, `working` (a spinner), `blocked` on you (`kind` `permission`, `question` or `auth`; in warning, its value beside its icon), `done` (a result not seen yet; lit) or `error` (in alert). A word it does not know is `idle`. A `watch` that ends takes `working` and `blocked` with it and leaves `done` and `error` to be seen.
- `enabled`: the ids of `items` that can be picked; unset, all.
- `items`: items that change, each `{ id, label, icon, glyphs, detail, active, enabled, done, hidden, busy, tone, verb, closes, actions }`, when the settings list none. A `done` item dims, struck through, and can still be picked; a `hidden` one leaves the rows and is found by filtering (`/`); `tone` (`warning`) marks one that needs attention, with `glyphs` before its detail so colour is not all that says so; a `busy` one, still being made, shows a spinner for its icon. `verb` names what choosing it does in the picker's legend (`tick`), `closes` hides the menu first, and `actions`, `[{ key, desc, icon, closes }]`, are its own menu (`M-` with its digit, `M-RET` while filtering), each running `run` with the item's id and the action's key.
- `empty`: why `items` is empty, shown in its place (`No devices paired`).

A line that is not a JSON object is logged and skipped. The shell ignores fields it does not know, and a plugin may read its own (`recording`'s `since`).

## Shipped

List one by name to use it: `plugins.dunst = { };`.

- **`command`:** the state its source gives, as above, under any name.
- **`dunst`:** do-not-disturb for dunst. A bell, struck and lit while notifications are paused; a click pauses or resumes them. Needs `dunstctl` and `dbus-monitor` on `PATH` (with Nix, add dunst to `extraPackages`).
- **`wallpaper`:** the wallpaper's name, from a source whose value is its path.
- **`recording`:** a pill on every screen while recording, and the elapsed time as a status. Its source gives `{"active": true, "since": <epoch seconds>}` while recording; `stop` ends it.
- **`dictation`:** a pill while dictating, a spinner while transcribing. Its source gives `recording`, `transcribing` or anything else for idle, as its value or its `stage` (`show.streaming.stage = "recording"`); `stop` ends it.
- **`niriMinimap`:** a minimap of niri's workspaces as you move between them. Sized by `height`, `maxWidth`, `opacity` and `borderWidth`.
- **`tasks`:** tasks to tick off, from the tasks file its `file` names (see [Tasks](tasks.md)). `done` and `reopen` are given a task's id and `add` a title, each writing the file again; `sync` runs as the menu opens on a file `syncAfter` minutes old (5), and after a tick; `remind`, unset by default, is given a title and a time as a timed task falls due.
- **`ask`:** a panel for quick turns with an agent, below.
- **`notifications`:** a notification server in the shell's look, below.

## Ask

A panel to ask an agent something without leaving what you are doing. It opens where the menu does, in the same frame, its prompt under the conversation and focused, being what it opens for, its keys in the bar beside the top level's statuses, the prompt saying who it asks (`placeholder`, by default "Ask {title}", after the prompt glyph every input shares, or its own `promptGlyph`) until a turn says what Return does next, and opening either closes the other. Its links show as rows, and a notification arrives when it answers while hidden, unless the menu shows the answer above the input that sent it.

The one required setting is `ask`: an agent speaking [ACP](https://agentclientprotocol.com) on its stdio. It starts with the first turn and stays for the next ones, so a turn skips its start and its session's loading; after `idle` minutes without one (10) it stops, and the next turn starts it again and loads the session. Its answer streams in as it writes it, in Markdown, ACP's text format (the one text the shell renders rich, because the agent is the one you configured): the conversation renders it (an image as its alt text, `<` as itself, so nothing is fetched), the menu's island shows it plain. A closing numbered list is the options a digit picks: its structure is the Markdown's own, never guessed from plain text.

```nix
# Claude, through Zed's ACP adapter; `open` resumes its session in a terminal.
plugins.ask = { title = "Claude"; ask = "claude-agent-acp"; open = "foot claude --resume"; };

# An agent on another machine, its stdio over SSH; a sync after any tool that writes the agenda.
plugins.ask = { ask = "ssh host hermes-acp"; cwd = "/srv/agent"; toolMatch = "^mcp__agenda__(?!list_)"; toolRun = "calendar-sync"; };
```

A turn resumes the session, or starts one and says so when the old one is gone; approvals are the agent's permission requests, `C-y` allowing once; stopping cancels the turn, and an agent still answering two seconds later is stopped. A failure ends the turn in alert, saying why ("Sign in to … first", the agent's own error), and the agent's stderr goes to the journal.

| Tested with | Version |
|---|---|
| ACP | protocol v1 |
| Hermes Agent (`hermes-acp`) | 0.22.7 |

Other ACP agents (Claude through `claude-agent-acp`, Codex through `codex-acp`, Gemini CLI, OpenCode, Goose) speak the same protocol and are untested here.

Other settings: `cwd` (where its sessions work, on the agent's machine; `$HOME`), `toolMatch` and `toolRun` (a command run once a turn that used a tool matching it ends), `open` (given the session, opens it in a terminal), `promptGlyph`, `placeholder`, `lines` (the conversation's height, 14), and `notify`, `pasteImage` and `encodeImage`, which default to `notify-send`, `wl-paste` and `base64`.

Keys:

- `RET` sends, `C-S-RET` sends and hides the panel, the answer arriving as a notification, `S-RET` breaks the line, `C-v` attaches the clipboard's image. The legend shows only what the state changes; with the prompt dim, `?` lists every key, any key closing the list.
- The prompt has the keys as the panel opens. `ESC` clears the prompt, then steps back: to the menu that opened the panel, else hiding it, as does a click beside it; the conversation is kept, and an empty one says so. `C-c` stops the run, refusing what it waits to be allowed; leaving never stops it.
- `C-y` allows an approval, which stays in the conversation as a dim line, `C-l` starts a new conversation, `C-o` moves it to a terminal, `C-r` lists its past conversations, filtered in the menu, as a shell's reverse search does, its legend naming it while the conversation is new; with the prompt dim, plain `l`, `o` and `r` do and `y` copies the last answer (allowing takes `C-y` only, so `y` never approves); `TAB` moves the keys between the prompt and the panel, as in a level.

Past conversations are the agent's own (ACP's `session/list`, where `cwd` says), in its order, each with its last activity, the open one lit. `RET` resumes one, its history replayed as the conversation (`session/load`), and its own menu (`M-RET`) has `o`, `open` given its session; an agent that cannot load them dims them, and one that cannot list them says so. The menu's input that gives it text takes `C-r` too, its list being Ask's `items`.

Its status (its name in a bar) shows its `glyph` only while it has something to report: a run, an answer unread, a question for you. To ask from a key, bind `menu press Tab`: the menu opens with its input focused.

Two agents are two plugins with `type = "ask"`. A level's `input` may hand one its text (see [Input](menu.md#input)).

## Notifications

A notification server in the shell's own look, in place of dunst or mako: list it only with no other daemon running. Quickshell speaks the protocol; the plugin decides what shows, for how long, and where.

Cards stack in a `corner` of the focused screen, newest by the corner, critical ones first. A card shows its app's icon, the summary in bold, the app on its right (and when it came, once it has waited a minute), the body in two lines, progress (`value`) as a meter, a picture (album art, a screenshot) on its right, and the sender's actions below, on the `actionSide` (`right`). A click opens a card, running its default action, else dismissing it; `✕` or a right click dismisses it.

A card shows for its sender's time, else `timeout.low` or `timeout.normal` seconds (3 and 8); a critical one stays until dismissed. Time holds while the pointer is on any card, which also holds the stack still, and after `idle` seconds without input (120), so none goes while you are away. One sent again, by its id or its stack tag (`x-dunst-stack-tag`, as volume tools send), replaces its card and starts its time again.

`limit` cards show at once (3), `+N` counting the rest. While paused, or while a fullscreen window has focus, cards wait, a struck bell counting them (not over a fullscreen window), and their time starts once they show; a critical one shows anyway. The plugin's status is a bell with the count, struck and lit while paused; a click summons the cards. Pause survives a reload.

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

`rules` apply in order, later ones winning. A rule applies when each regular expression in its `match` is found in its field (`app`, `summary`, `body`, `category`, `urgency`, `desktopEntry`; anchor one with `^…$`). It can set:

- `hide`: drops it.
- `timeout`: the seconds it shows; 0, never.
- `urgency` (`low`, `normal`, `critical`): how it shows and lasts.
- `ignorePause`: lets it through a pause, as a critical one goes.
- `actions`: its own, each a menu entry's `{ key, desc, cmd }` on a letter you choose (any but `x`), after its reply and before its sender's. Running one dismisses its card; `closes = false` keeps it.
- `default`: what opening it runs, in place of its sender's.
- `run`: a command run as it arrives, not when it is replaced.

A command gets the notification in its environment, never in its text, as dunst's scripts get `DUNST_*`: `NOTIFICATION_APP`, `NOTIFICATION_SUMMARY`, `NOTIFICATION_BODY`, `NOTIFICATION_URGENCY`, `NOTIFICATION_ID`, `NOTIFICATION_ICON` (its icon as sent: a file's path, as a screenshot or album art comes, else a name), and each named group of its `match` (`(?<code>\d{6})` as `NOTIFICATION_CODE`), which a `desc` shows by name (`{code}`). A rule's fields are checked as the configuration builds.

Cards never take the keys on their own, so a notification never takes your typing. `summon`, bound to a compositor key (`Mod+N` through `action summon`, the plugin's `shortcut` naming it), gives them the keys where they are, the newest picked. Their keys show where they act, and nothing moves. Summoned, held cards show too, `limit` at a time (at most 9), critical ones staying by the corner while the rest scroll, the bar counting those not shown (`+2`). The bar holds the keys the state changes (`C-p` pause or resume, `?`); `?` lists the rest, any key closing the list. `hint` shows the `shortcut` dimly by the cards at rest. Keys:

- A digit picks a card by its place among all, so it holds still, scrolling it into view; `↑↓` move the pick as the cards show, scrolling past the last one.
- The picked card's letters run its actions (from their labels, never `x`); the keys stay, so one summon can clear several.
- `RET` opens it and lets go; `x` dismisses it, the pick moving on.
- `C-X` clears all; `C-r` brings back the last closed (of 20 kept, not those a sender marks transient), to read; `C-p` pauses or resumes.
- `ESC`, or a click beside the cards, lets go.

A key path runs as typing it would: `notifications press "2 x"`.

A card whose sender takes a reply offers it first among its actions, on `TAB`. The prompt takes the actions' place and the body a line, so the card keeps its height. `RET` sends it and lets go, as the reply closes the card; the keys stay only on a card its sender keeps (`resident`), which shows what you sent on one line. `C-S-RET` sends it and lets go always. `ESC` clears it; empty, `ESC` goes back to the card's keys. A card keeps its own unsent reply until it goes. A card its sender closes while you type stays, the bar saying so, until you leave the prompt: `RET` then copies your text, so none is lost.

Actions for a binding (`qs -c quick-key ipc call notifications action <name>`) or an entry: `summon` gives the cards the keys, `invoke` opens the newest card, `dismiss` dismisses it, `clear` dismisses every one, `restore` brings back the last closed, `pause` pauses or resumes. Another daemon holding the bus shows as the plugin's error; `owner`, a command printing the process that holds it, makes that check (`busctl`).

`width` sets the cards' width (480).

## Writing one in QML

A plugin that needs behaviour (a timer, a surface, a protocol) is a folder, found in `$XDG_CONFIG_HOME/quick-key/plugins/` and then among the shipped ones. `type` names it, by default the plugin's own name, or gives a path to its file.

- `<Name>.qml`, rooted at `Plugin`: its state and actions. It never draws.
- `Settings.qml`, rooted at `PluginSettings`: every setting it takes, with its default. It is read as the configuration builds, so it must stay declarative; the shell creates it once to check the config and once to run the plugin.
- One file per view it draws, listed in `views` (`["Minimap.qml"]`). Each is given the plugin as `plugin` and only reads it.

What it gets:

- `name`, `settings` (its part of the config), and `state` (the state line, with `show` and `items` applied).
- `exec(setting, ...args)` runs a command setting; `call(setting, args, then)` runs one and always answers `then(code, output)` when it is done (127 when unset), so a second call never drops a command still running, and one that exits non-zero is logged with its last line on stderr; `commandLine(setting, ...args)` builds one for a `Process`. Arguments arrive as `$1`, `$2`.
- The theme (`Config.theme`), the [kit](kit.md), and the services: `Audio`, `Network`, `Bluez`, `Power`, `Brightness`, `Music`, `Tray`, `Compositor`, `Niri` for niri's own events, and `Picker` (`pick(list)` shows a list by name filtered on a menu level of its own, over the plugin's panel, which Escape shows again), and `Panels`, the stack of surfaces: `open(owner)` shows a plugin's panel on top, `back()` closes it to show what it covered, `close()` hides them all.

What it gives:

- `glyph`, `text`, `detail`, `glyphs` (before the detail, in its tone), `active` and `tone`, shown wherever its name is a `status`, and `fields` by name for an entry's `format`.
- `fieldTones`: a tone per field, kept when a `format` shows it (`{ updated: "warning" }` on an old sync).
- `error`: why its source or its last action failed, by default its state's own `error`; a level listing it shows it beside its keys, in `alert`.
- `activate()` for a click on it in a bar, and `refresh()`, called as the menu opens.
- `items`, `select(id)` and `run(id, key)` (an action from an item's own menu) for an entry whose `list` is its name; an item may bring a `meter` (0 to 1).
- `actions`: actions by name, as the built-in ones (`{ icon, detail, available, run }`), which an entry of a level listing it names in its `action` (the tasks' `sort`).
- `words`: what only it says (its empty list, its failures), as `Words` holds the words the surfaces share; a plugin never adds to `Words`.
- `submit(text, background, after)` for an input's text when it sets no `cmd`: false if not taken (the input keeps it), as a plugin without one does; `after` run once done. `busy` while it takes no text, which shows a spinner in the input: its `phase` working or blocked, which it sets rather than `busy`.
- `watched` while the menu shows an input giving it text, set as a visit starts, and `visitEnded` (through `endVisit()`) as it ends: the input or its plugin changes, or the menu closes; `turn`, `{ question, context, text, phase, kind, activity, options, table, steps }`, the conversation's turn as the menu draws it while watched, `phase` and `kind` as a state line's are: `working` (with `activity`, and `context` the answer it follows), `done`, `blocked` on a `question` (`options` a digit picks) or for `permission`, `error` (the input getting the text back) or `idle` once stopped, and `steps` what you answered on the way (an approval); null before the first.
- `recall()` to show its past conversations filtered in the menu, for `C-r` in an input giving it text, while `recalls`: the picker opens over what asked for it.
- `expand()` to show the conversation in its own panel over the menu, when the answer over the input cannot fit it; stepping back shows the menu again where it was, the visit going on; false without a panel.
- `empty`: why its list is empty, shown in its place; by default its state's own `empty`.
- `shortcut`, its compositor key.

Every plugin answers `<name> activate`, `<name> refresh` and `<name> action <action>` over IPC, the last running one of its `actions` as an entry naming it would.
