# Plugins

A plugin adds a status, a list or a surface. List it by name under `plugins`, with its settings beside it. Nothing loads unlisted, and one that fails to load is logged and left out.

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

For a fixed set of choices, `items` lists them, each `{ id, label, icon, detail }`, for an entry whose `list` is the plugin's name. The source's value names the one in use, and `select` runs with the chosen `id`.

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
- `enabled`: the ids of `items` that can be picked; unset, all.
- `items`: items that change, each `{ id, label, icon, glyphs, detail, active, enabled, done, hidden, busy, tone }`, when the settings list none. A `done` item dims, struck through, and can still be picked; a `hidden` one leaves the rows and stays in the level's picker; `tone` (`warning`) marks one that needs attention, with `glyphs` before its detail so colour is not all that says so; a `busy` one, still being made, shows a spinner for its icon.
- `empty`: why `items` is empty, shown in its place (`No devices paired`).

A line that is not a JSON object is logged and skipped. The shell ignores fields it does not know, and a plugin may read its own (`recording`'s `since`).

## Shipped

List one by name to use it: `plugins.dunst = { };`.

- **`command`:** the state its source gives, as above, under any name.
- **`dunst`:** do-not-disturb for dunst. A bell, struck and lit while notifications are paused; a click pauses or resumes them. Needs `dunstctl` and `dbus-monitor` on `PATH` (with Nix, add dunst to `extraPackages`).
- **`wallpaper`:** the wallpaper's name, from a source whose value is its path.
- **`recording`:** a pill on every screen while recording, and the elapsed time as a status. Its source gives `{"active": true, "since": <epoch seconds>}` while recording; `stop` ends it.
- **`dictation`:** a pill while dictating, a spinner while transcribing. Its source gives `recording`, `transcribing` or anything else for idle; `stop` ends it.
- **`niriMinimap`:** a minimap of niri's workspaces as you move between them. Sized by `height`, `maxWidth`, `opacity` and `borderWidth`.
- **`tasks`:** tasks to tick off, from the tasks file its `file` names (see [Tasks](tasks.md)). `done` and `reopen` are given a task's id and `add` a title, each writing the file again; `sync` runs as the menu opens on a file `syncAfter` minutes old (5), and after a tick; `remind`, unset by default, is given a title and a time as a timed task falls due.
- **`ask`:** a panel for quick turns with an agent, below.

## Ask

A panel to ask an agent something without leaving what you are doing. It opens where the menu does, in the same frame, its prompt under the conversation and its keys in the bar beside the top level's statuses, the prompt saying who it asks (`placeholder`, by default "Ask {title}", after the prompt glyph every input shares, or its own `promptGlyph`) until a turn says what Return does next, and opening either closes the other. Its links show as rows, and a notification arrives when it answers while hidden, unless the menu shows the answer above the input that sent it.

The one required setting is `ask`: an agent speaking [ACP](https://agentclientprotocol.com) on its stdio. It starts with the first turn and stays for the next ones, so a turn skips its start and its session's loading; after `idle` minutes without one (10) it stops, and the next turn starts it again and loads the session. Its answer streams in as it writes it, in Markdown, ACP's text format: the conversation renders it (an image as its alt text, `<` as itself, so nothing is fetched), the menu's island shows it plain. A closing numbered list is the options a digit picks.

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

Other settings: `cwd` (where its sessions work, on the agent's machine; `$HOME`), `toolMatch` and `toolRun` (a command run once a turn that used a tool matching it ends), `open` (given the session, opens it in a terminal), `title`, `glyph`, `promptGlyph`, `placeholder`, `lines` (the conversation's height, 14), and `notify`, `pasteImage` and `encodeImage`, which default to `notify-send`, `wl-paste` and `base64`.

Keys:

- `RET` sends, `C-S-RET` sends and hides the panel, the answer arriving as a notification, `S-RET` breaks the line, `C-v` attaches the clipboard's image. The legend shows only what the state changes; with the prompt dim, `?` lists every key, any key closing the list.
- The prompt has the keys as the panel opens. `ESC` steps back: denies an approval, else stops the run, else lets the digits type over waiting options, else clears the prompt, else leaves it, dim, else hides, as does a click beside it; the conversation is kept, and an empty one says so.
- `C-y` allows an approval, which stays in the conversation as a dim line (and a denial too), `C-l` starts a new conversation, `C-o` moves it to a terminal; with the prompt dim, plain `l` and `o` do and `y` copies the last answer (allowing takes `C-y` only, so `y` never approves); `TAB` moves the keys between the prompt and the panel, as in a level.

Two agents are two plugins with `type = "ask"`. A level's `input` may hand one its text (see [Input](menu.md#input)).

## Writing one in QML

A plugin that needs behaviour (a timer, a surface, a protocol) is a folder, found in `$XDG_CONFIG_HOME/quick-key/plugins/` and then among the shipped ones. `type` names it, by default the plugin's own name, or gives a path to its file.

- `<Name>.qml`, rooted at `Plugin`: its state and actions. It never draws.
- `Settings.qml`, rooted at `PluginSettings`: every setting it takes, with its default.
- One file per view it draws, listed in `views` (`["Minimap.qml"]`). Each is given the plugin as `plugin` and only reads it.

What it gets:

- `name`, `settings` (its part of the config), and `state` (the state line, with `show` and `items` applied).
- `exec(setting, ...args)` runs a command setting; `commandLine(setting, ...args)` builds one for a `Process`. Arguments arrive as `$1`, `$2`.
- The theme (`Config.theme`), the [kit](kit.md), and the services: `Audio`, `Network`, `Bluez`, `Power`, `Brightness`, `Music`, `Tray`, `Compositor`, and `Niri` for niri's own events.

What it gives:

- `glyph`, `text`, `detail`, `glyphs` (before the detail, in its tone), `active` and `tone`, shown wherever its name is a `status`, and `fields` by name for an entry's `format`.
- `fieldTones`: a tone per field, kept when a `format` shows it (`{ updated: "warning" }` on an old sync).
- `error`: why its source or its last action failed, by default its state's own `error`; a level listing it shows it beside its keys.
- `activate()` for a click on it in a bar, and `refresh()`, called as the menu opens.
- `items` and `select(id)` for an entry whose `list` is its name; an item may bring a `meter` (0 to 1).
- `submit(text, background, after)` for an input's text when it sets no `cmd`: false if not taken (the input keeps it), as a plugin without one does; `after` run once done. `busy` while it takes no text, which shows a spinner in the input.
- `watched` while the menu shows an input giving it text, which ends a visit each time that changes; `turn`, `{ question, context, text, phase, activity, options, table, steps }`, the conversation's turn as the menu draws it while watched, `phase` one of `working` (with `activity`, and `context` the answer it follows), `answered`, `choosing` (`options` a digit picks), `waiting` (on you), `failed` (the input getting the text back) or `stopped`, and `steps` what you answered on the way (an approval); null before the first.
- `expand(back)` to show the conversation in its own panel, when the answer over the input cannot fit it: `back(true)` when left by stepping back, so the menu shows again where it was, `back(false)` when left any other way; false without a panel.
- `empty`: why its list is empty, shown in its place; by default its state's own `empty`.
- `shortcut`, its compositor key.

Every plugin answers `<name> activate` and `<name> refresh` over IPC.
