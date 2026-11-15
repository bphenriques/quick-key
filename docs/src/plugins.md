# Plugins

A plugin is a QML file whose root is `Plugin`, listed by name under `plugins` in `config.json` as `{ source, settings }`. `source` names the plugin implementing it (`command`), by default its own name, or is a path to a QML file. A plugin's file is its name capitalised (`niriMinimap`: `NiriMinimap.qml`), alone or in a folder of that name with its own pieces (`ask/Ask.qml` beside `ask/AskPanel.qml`), which it creates by path since the folder is not a module. It is found in `$XDG_CONFIG_HOME/quick-key/plugins/`, then among the shipped ones. Nothing loads unlisted; one that fails to load is logged and left out, and the shell runs on.

Its API, and the only one:

- In: `name`; `settings`, its own part of the config, which holds the defaults (`settings.height ?? 30`); and `state`, what its source last gave (see Sources below).
- Commands: a setting holding a command runs through `exec(setting, ...args)`, or `commandLine(setting, ...args)` for a `Process`, its arguments passed as `$1`, `$2`.
- Out: `glyph`, `text` and `detail`, shown by a menu entry whose `status` is its name and in the header when `menu.header` names it; `active`, which lights either; `tone`, when its status needs one (`alert` for do-not-disturb); `activate()`, what a click on its header item does; `refresh()`, called as the menu opens, which reads a `read` source again; `items`, what a menu entry with `list` set to its name shows, each `{ id, label, icon, detail, active, enabled }`, and `select(id)`, what choosing one does; and `shortcut`, its compositor key, shown while Super is held (`settings.shortcut` by default). The module rejects either naming a plugin not listed, and a plugin taking a built-in name.
- Uses: the theme (`Config.theme`, `Config.popups`), the kit, and the services' APIs (`Audio`, `Network`, `Bluez`, `Power`, `Brightness`, `Music`, `Tray`, `Startup`, `Compositor`), plus a compositor's own backend when it is built on one (`Niri`, whose `received` passes on every event).
- IPC: every plugin answers `<name> activate` and `<name> refresh`, which compositor keys call through `exec.ipc`.

| Shipped | Shows | Settings |
|---|---|---|
| `Command.qml` | the state its command gives, under any name (`source = "command"`) | a source (see Sources), `activate`, `select` (given the item's id), `shortcut` |
| `DoNotDisturb.qml` | do-not-disturb: a bell, red while notifications are paused; a click pauses or resumes | a source (`true` or `false`, or a state line with `active`), `activate`, `shortcut` |
| `Ask.qml` | a panel for quick turns with an agent, its keys below; a reply's links as rows; the tool in use while waiting, a knock while an approval waits; a notification while hidden; lit while waiting or unread, in the warning colour while an approval waits | `ask` (prompt, session, image: a JSON object per line, `{run, session}`, `{status}`, `{approval}`, then `{session, reply}` or `{error}`), `approve` (run, allow or deny), `stop` (run), `notify` (title, text; prints `default` when clicked), `pasteImage` (file; fails when the clipboard holds no image), `open` (session), `title`, `glyph` |
| `Dictation.qml` | a dim pill on every screen while dictating, top right one slot under the recording pill: its icon while it listens (dim while the mic is muted), a spinner while it transcribes; a click stops it; lit while dictating | a source whose text is `recording`, `transcribing` or anything else for idle, `stop`, `glyph` |
| `Recording.qml` | a pill on every screen while recording, a click stops it; status: the time, lit while recording | a source: `{"active": true, "since": <epoch seconds>}` while recording, empty otherwise; `stop` |
| `Wallpaper.qml` | status: the wallpaper's name | a source whose text is the wallpaper's path or name |
| `NiriMinimap.qml` | a minimap of niri's workspaces as you move between windows or workspaces | `height`, `maxWidth`, `opacity`, `borderWidth` |

`Ask.qml`'s keys: `RET` sends (a failed or stopped prompt sent again replaces its exchange), `S-RET` breaks the line, `C-v` attaches the clipboard's image when it holds one. `ESC` steps back: denies an approval, else stops the run, else clears the prompt and image, else hides; twice quickly hides from anywhere, never losing the conversation. `C-y` allows an approval, `C-l` starts a new conversation, `C-o` moves it to a terminal between runs.

Only `ask` is required, and its smallest form prints one line, `{"session", "reply"}` or `{"error"}`; ended without either, its last line on stderr is the error. The rest adds on: `{run}` lets `stop` reach the run, `{status}` names what it is doing, and `{approval}` with `approve` asks before it acts. Without `stop`, stopping closes the stream. Claude Code, carrying on in its session:

```nix
plugins.ask.settings = {
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

Each `ask` names its own plugin, so two agents are two plugins with `source = "ask"`.

## Sources

A plugin's state comes from one source, set in its settings:

- `watch`: a command that runs for as long as it lasts, each line replacing the state. Its state lasts while it runs; restarted when it exits, waiting longer each time it exits without output.
- `read`: a command run at start, as the menu opens, and on `qs -c quick-key ipc call <name> refresh`, its last line replacing the state. For what has no events.
- `file`: a file the tool writes, read again on every change, even before it exists; a relative path is under `$XDG_RUNTIME_DIR`.

A line is a JSON object, `{"glyph", "text", "detail", "active", "tone", "items"}`, each field optional, or plain text, which becomes `text`. Each line replaces the whole state, and an empty one clears it; a line that is not a JSON object is logged and skipped. The shell ignores fields it does not know, and a plugin may read its own (`Recording.qml`'s `since`). `Ask.qml` keeps its own request and reply lines: a conversation, not state. `items` fill a menu level whose entry sets `list` to the plugin's name; `select` runs with the chosen item's `id`, and a `read` plugin is read again once it is done, so the item in use lights.

A `watch` command must flush each line (`stdbuf -oL`, `--line-buffered`), or nothing shows until its buffer fills.

```json
"plugins": {
  "vpn": { "source": "command", "settings": { "watch": "vpn-status --follow", "activate": "vpn-toggle" } },
  "displayLayout": { "source": "command", "settings": { "read": "display-layouts", "select": "display-layout" } }
}
```
