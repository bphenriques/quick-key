# Integrations

An integration is one QML file whose root is `Integration`, listed by name under `settings.integrations` as `{ source, settings }`, set by the config that owns the tool. `source` is a path, so your own can live anywhere, or relative to the shell; left out, it is the one shipped under that name (`workspace-map`: `integrations/WorkspaceMap.qml`). Nothing loads unlisted; one that fails to load is logged and left out, and the shell runs on.

Its API, and the only one:

- In: `name`, and `settings`, its own part of the config; it holds the defaults (`settings.height ?? 30`).
- Commands: a setting holding a command runs through `exec(setting, ...args)`, or `commandLine(setting, ...args)` for a `Process`, its arguments passed as `$1`, `$2`; one that prints as it goes is followed by `CommandWatcher` (each line on `read`, restarted a moment after it exits), one read whole on demand by `CommandReader`.
- Out: `glyph`, `text` and `detail`, shown by a menu entry whose `status` is its name and in the header when `menu.header` names it; `active`, which lights either; `activate()`, what a click on its header item does; and `shortcut`, its compositor key, shown while Super is held. The module rejects either naming an integration not listed, and an integration taking a built-in name.
- Uses: the theme (`Config.theme`, `Config.popups`), the kit, and the services' APIs (`Audio`, `Network`, `Bluez`, `Power`, `Display`, `Brightness`, `Music`, `Tray`, `Startup`, `Compositor`), plus a compositor's own backend when it is built on one (`Niri`, whose `received` passes on every event).
- Actions: an `IpcHandler` targeting its name, which menu entries and compositor keys call through `exec.ipc`.

| Shipped | Shows | Settings |
|---|---|---|
| `Ask.qml` | a panel for quick turns with an agent, its keys below; a reply's links as rows; the tool in use while waiting, a knock while an approval waits; a notification while hidden; lit while waiting or unread | `ask` (prompt, session, image: a JSON object per line, `{run, session}`, `{status}`, `{approval}`, then `{session, reply}` or `{error}`), `approve` (run, allow or deny), `stop` (run), `notify` (title, text; prints `default` when clicked), `pasteImage` (file; fails when the clipboard holds no image), `open` (session), `title`, `glyph` |
| `Dictation.qml` | a dim pill on every screen while dictating, top right one slot under the recording pill: its icon while it listens (dim while the mic is muted), a spinner while it transcribes; a click stops it; lit while dictating | `status` (prints `recording`, `transcribing` or anything else for idle, one per line as it changes), `stop`, `glyph` |
| `Recording.qml` | a pill on every screen while recording, a click stops it; status: the time, lit while recording | `file` (under `$XDG_RUNTIME_DIR`), `stop` |
| `Wallpaper.qml` | status: the wallpaper's name | `file` (under `$XDG_RUNTIME_DIR`) |
| `WorkspaceMap.qml` | a minimap of niri's workspaces as you move between windows or workspaces | `height`, `maxWidth`, `opacity`, `borderWidth` |

`Ask.qml`'s keys: `RET` sends (a failed or stopped prompt sent again replaces its exchange), `S-RET` breaks the line, `C-v` attaches the clipboard's image when it holds one. `ESC` steps back: denies an approval, else stops the run, else clears the prompt and image, else hides; twice quickly hides from anywhere, never losing the conversation. `C-y` allows an approval, `C-l` starts a new conversation, `C-o` moves it to a terminal between runs.

