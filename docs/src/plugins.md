# Plugins

A plugin adds a status, a list or a surface, listed by name under `plugins` in `config.json`, where it holds its settings. Most need no QML: the `command` plugin is made of a source and data. Nothing loads unlisted; one that fails to load is logged and left out, and the shell runs on. The module rejects a menu entry naming a plugin not listed, and a plugin taking a built-in name.

## Without QML

`type = "command"`, under any name. Its source gives a value; `show` says how each value looks.

```nix
plugins.doNotDisturb = {
  type = "command";
  watch = "dnd-status --follow";             # prints true or false on every change
  activate = "dnd-toggle";                   # a click on its header item
  show = {
    "true"  = { glyph = "󰂛"; tone = "alert"; active = true; };
    "false" = { glyph = "󰂚"; };
  };
};
```

For dunst, the shipped `dunst` plugin is this, ready to list: `plugins.dunst = { };`.

The source is how the tool tells you, one of three:

- `watch`: the tool has events. A command run for as long as it lasts, each line the new state; restarted when it exits, waiting longer each time it exits without output. It must flush each line (`stdbuf -oL`, `--line-buffered`).
- `file`: the tool writes its state. Read again on every change, even before it exists; a relative path is under `$XDG_RUNTIME_DIR`.
- `read`: neither. A command whose last line is the state, run at start and as the menu opens, which is when anything it shows is seen; `every` (seconds) runs it again while the menu stays open, for what changes as you look (a CPU's load). On `qs -c quick-key ipc call <name> refresh` too.

`show` maps each value to `{ glyph, text, detail, active, tone }`; a value without one is shown as text. `items` lists what never changes, each `{ id, label, icon, detail }`, for a menu entry whose `list` is the plugin's name: the source's value names the item in use, which lights and gives the status its label and icon, and `select` runs with the chosen item's `id`, the source read again once it is done.

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
- `items`: items that change, each `{ id, label, icon, detail, active, enabled }`, when the settings list none.

A line that is not a JSON object is logged and skipped. The shell ignores fields it does not know, and a plugin may read its own (`recording`'s `since`).

## With QML

A plugin that needs behaviour (a timer, a surface, a protocol) is a folder holding all of it: `<Name>.qml`, rooted at `Plugin`, holds its state and actions and never draws; `Settings.qml`, rooted at `PluginSettings`, declares every setting it takes with its default; and each view it draws is a file of its own beside them. `type`, beside its settings, names the plugin implementing it, by default its own name, or is a path to a plugin's file. Its folder is its name (`niriMinimap/NiriMinimap.qml`), found in `$XDG_CONFIG_HOME/quick-key/plugins/`, then among the shipped ones.

Its API, and the only one:

- In: `name`; `settings`, its part of the config read through its `Settings.qml` (`settings.height`), a key it does not declare logged and left out; and `state`, the state line over `show` and `items`, as above.
- Commands: a setting holding a command runs through `exec(setting, ...args)`, or `commandLine(setting, ...args)` for a `Process`, its arguments passed as `$1`, `$2`.
- Out: `glyph`, `text` and `detail`, shown by a menu entry whose `status` is its name and in the header when `menu.header` names it; `active`, which lights either; `tone`, when its status needs one; `activate()`, what a click on its header item does; `refresh()`, called as the menu opens, which reads a `read` source again; `items`, what a menu entry with `list` set to its name shows, and `select(id)`, what choosing one does; and `shortcut`, its compositor key, shown while Super is held (`settings.shortcut` by default).
- Uses: the theme (`Config.theme`, `Config.popups`), the kit, and the services' APIs (`Audio`, `Network`, `Bluez`, `Power`, `Brightness`, `Music`, `Tray`, `Startup`, `Compositor`), plus a compositor's own backend when it is built on one (`Niri`, whose `received` passes on every event).
- Views: `views` lists the files it draws with (`["Minimap.qml"]`), each created with the plugin and given it as `plugin`; a view only reads the plugin, and decides itself when it shows. Its folder is not a module the shell imports, which is why the plugin names them rather than declaring them.
- IPC: every plugin answers `<name> activate` and `<name> refresh`, which compositor keys call through `exec.ipc`.

| Shipped | Shows | Settings |
|---|---|---|
| `command` | the state its source gives, under any name (`type = "command"`) | a source, `show`, `items`, `activate`, `select` (given the item's id), `shortcut` |
| `dunst` | do-not-disturb for dunst: a bell, red while notifications are paused; a click pauses or resumes them | defaults naming `dunstctl` and `dbus-monitor` (on `PATH`; with Nix, add dunst to `extraPackages`) for its source and `activate`, and the bells in `show`, which a `show` of your own replaces whole; `shortcut` |
| `ask` | a panel for quick turns with an agent, its keys below; a reply's links as rows; the tool in use while waiting, a knock while an approval waits; a notification while hidden; lit while waiting or unread, in the warning colour while an approval waits | `ask` (prompt, session, image: a JSON object per line, `{session}`, `{status}`, `{approval}`, then `{reply}` or `{error}`; `allow` or `deny` arrives on its stdin), `notify` (title, text; prints `default` when clicked; `notify-send` by default, empty for none), `pasteImage` (file; fails when the clipboard holds no image; `wl-paste` by default), `open` (session), `title`, `glyph` |
| `dictation` | a dim pill on every screen while dictating, top right one slot under the recording pill: its icon while it listens (dim while the mic is muted), a spinner while it transcribes; a click stops it; lit while dictating | a source whose value is `recording`, `transcribing` or anything else for idle (`show` can give a value its `phase`), `stop`, `glyph` |
| `recording` | a pill on every screen while recording, a click stops it; status: the time, lit while recording | a source: `{"active": true, "since": <epoch seconds>}` while recording, empty otherwise; `stop` |
| `wallpaper` | status: the wallpaper's name | a source whose value is the wallpaper's path or name |
| `niriMinimap` | a minimap of niri's workspaces as you move between windows or workspaces | `height`, `maxWidth`, `opacity`, `borderWidth` |

`Ask.qml`'s keys: `RET` sends (a failed or stopped prompt sent again replaces its exchange), `S-RET` breaks the line, `C-v` attaches the clipboard's image when it holds one. `ESC` steps back: denies an approval, else stops the run, else clears the prompt and image, else hides; twice quickly hides from anywhere, never losing the conversation. `C-y` allows an approval, `C-l` starts a new conversation, `C-o` moves it to a terminal between runs.

Only `ask` is required, and its smallest form prints one line, `{"session", "reply"}` or `{"error"}`; ended without either, its last line on stderr is the error. The rest adds on: `{session}` as the turn starts keeps the conversation when it is stopped, `{status}` names what it is doing, and `{approval}` asks before it acts, the answer a line on its stdin, `allow` or `deny`. That stdin stays open for the turn, so a tool that reads its own takes `</dev/null`. Stopping ends the command (SIGTERM); one whose run lives elsewhere traps that to stop it there, and the next prompt waits until it has ended. Claude Code, carrying on in its session:

```nix
plugins.ask = {
  title = "Claude";
  ask = lib.getExe (pkgs.writeShellApplication {
    name = "ask-claude";
    runtimeInputs = [ pkgs.claude-code pkgs.jq ];
    text = ''
      resume=()
      if [ -n "$2" ]; then resume=(--resume "$2"); fi
      claude -p "$1" "''${resume[@]}" --output-format json </dev/null \
        | jq -c 'if .is_error then {error: .result} else {session: .session_id, reply: .result} end'
    '';
  });
  open = "foot claude --resume";
};
```

Each `ask` names its own plugin, so two agents are two plugins with `type = "ask"`.
