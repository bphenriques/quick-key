# Agent Instructions

A Quickshell menu and its home-manager module. What it does is in [README.md](./README.md) and the docs. This file is the rules.

## Design rules

Every change follows these; a change that cannot is a reason to revisit the rule here first, not to work around it.

1. **Data, not code.** What the menu shows and does comes from `menu.entries`. QML has no case for a particular entry, tool or device; a new need becomes a setting in `Config.qml`, with a check in `Validation.qml` when it can be wrong. A built-in (status, list, state, action) is one entry in its table, never a `case` or name test elsewhere.
2. **Tools through the config.** QML runs nothing by name. The config that owns a tool sets its command, and a default may name only a standard tool (`systemd-inhibit`, `notify-send`, Wayland's `wl-paste`), or, in a plugin named after a tool, that tool: listing the plugin is choosing it. The shell reads only output it defines (the state line, see [Sources](docs/src/plugins.md#sources)), never a tool's own format. What needs more of one tool is a plugin. The compositor is reached only through `Compositor` (see [Compositor](docs/src/compositor.md)). The one exception: a link opens with the desktop's handler for links.
3. **Events over polling.** What has no events is read when the menu opens.
4. **Layout is declared.** A level is an optional bar floating over its body. The top level's bar is `menu.header`; an entry may declare its own `header` with the same slots, and a level without one is its body alone. A slot holds entries, drawn as their status or else their icon, and statuses and plugins by name; a bar entry may do nothing but show its status. A body is a menu, its keys on its rows, or a view (`calendar`), its keys in a legend; both share the surface, hints and tones. A level's width comes from its entry (`width`, else `menu.width`) and its columns from `menu.columns`, never measured from what it shows, so it holds still; entries flow across, so order decides neighbours. At the top the columns are equal, so values line up; in a level the last hugs its rows against the right edge. Make the menu wider before adding columns or truncating. The menu and a plugin's panel (Ask) share one frame, `Panel`: the same place, a bar over a body over an optional input, one open at a time. An entry's `input` floats under its level's body, its text given to its `cmd` or else to the plugin the level lists.
5. **Order is explicit.** Top level by `lib.mkOrder`, rows pairing related things. Within a level, the list order, paired for the row it shares.
6. **Labels.** Sentence case; `...` when it opens a picker or an app; a pair named for what it changes (`Volume`, `Track`). A row's label is its `desc` and never changes; what its status reports sits on its right (rule 8). A bar holds content (a song, its modes), never a title; only an app's menu, which no entry names, names itself there (`blueman › Plugins`). Device levels put Power on `p` and Configure... on `c`; every row of a level carries an icon (an `action` brings its own, showing its state: Wi-Fi off, Bluetooth on); `space` is only ever a picker. What ends the session takes Shift (Reboot, Shutdown).
7. **Keys hold still.** Letters are actions and digits are list items. Ctrl reaches the bar and Alt an item's own menu, and they compose: in the body `1` runs an item and `M-1` opens its menu, in the bar `C-1` and `C-M-1`; a bar entry declares its key plain (`c`) and takes it with Ctrl (`C-c`). Own menus keep letters from the labels their apps supply. Holding Ctrl a second lists the bar's keys in place of the body, each named, as icons alone cannot say what they run; holding Super, each bar entry's `shortcut`, its compositor key. A body key may carry Ctrl or Alt in its name where its bar does not take it (`Ctrl+Left`, as niri writes bindings); hints show keys Emacs-style, `C-` Ctrl, `M-` Alt, `s-` Super, Shift as the capital letter (`C-←→`, `s-k`), symbols for the arrows, `DEL` for Backspace and `ESC` for Escape as Emacs writes them; a modifier never runs the plain key, Shift only picks the capital letter, and Super stays the compositor's. An input takes letters only while focused, so keys hold still: its key (`a` by convention) or a click focuses it, `RET` sends and keeps it focused, and `ESC` clears it, then leaves it, dim, then steps back as the panel does. A level's input starts waiting, Ask's focused, being what it opens for; waiting, a panel's own letters act (Ask's `y`, `l`, `o`, also `C-` while typing). Pinned items keep their digit and dim while absent, and their label names them wherever the menu shows them; the rest follow by name (internal audio first), never by signal or recency.
8. **State is visible.** The menu shows state, the OSD shows changes. A row's status and a listed item's detail sit on its right as data, values in a column; an action's value in its level, alone in reporting, follows its label instead. It is the status's short value, or the entry's `format` over its fields, shortened when it does not fit. A level's state sits on the row that changes it: a device's volume beside it, brightness on Brightness, power in Power's icon. Tone goes to what reports, never to a label beside it: a listed item in use and a toggle that is on (`activeWhen`) take `primary`, and so does the in-use item's value; a value's tone is its own (`warning` on a late count). The right of a row never holds a word for a state its icon or tone already shows; a status names its state only when it has no value to show (`off`, `muted`, `paused`). An empty list says why: off, or nothing found (a plugin through its `empty`); a level whose source failed says why under its keys, in `alert`. What cannot run right now dims, so keys hold still; what can never run on this machine is not declared. A listed item that is done (a ticked task) dims too, struck through, and still runs: struck, a dim row is finished, not unavailable. A listed item's value may take a tone of its own for a state that needs attention, its label staying plain (`warning` on a late task's date).
9. **Text is plain.** Everything renders through `Label`, which never interprets markup: titles from apps and streams are untrusted. The one source-specific case in the core is next to it: Music reads song and artist out of the XML some radio streams (Bauer Media) send as their title, since MPRIS leaves no glue to do it in.
10. **Done means seen working.** A change is tested where it runs (see [DEVELOPMENT.md](DEVELOPMENT.md)), not only evaluated.
11. **Widgets compose the kit.** Colour and dimming come from a `tone`, glyphs go through `Icon`, the wheel through `WheelSteps`, a colour that is data (a calendar's) through `Swatch`, a size in characters or lines through `Metrics`, outlines and dividers through `Surface`, `Pill` and `Divider` (the theme's `border` and `borderWidth`, a pill's tone only for a state), emphasis through `Label`'s `strong`, a surface the keyboard opens through `Panel`; a widget never sets opacity to dim, picks a theme colour or size itself, or draws a glyph as text.
12. **The core is what every desktop has.** Audio, network, Bluetooth, power, outputs and backlight, tray, music, the calendar. Anything tied to one tool or taste is a plugin: off until listed, reaching the shell only through its API (see [Plugins](docs/src/plugins.md)), and held to these rules like the core, keyboard first and built from the kit.
13. **Motion confirms, never delays.** Surfaces fade in and out, colours ease, all over `theme.animationDuration` (`0` for none) and through the kit (`Fade`, `Label`, `Icon`), never a widget's own; a highlight follows the pointer at once, as easing trails it. Nothing waits on an animation: a key acts at once, the menu appears and closes at once (its background blur cannot fade with it, and a fade-out would hold the keyboard), and nothing moves or resizes.

## Layout

The shell, under `packages/quick-key/`:

- `services/`: state read from its source (D-Bus, Pipewire, niri, commands), pushed by events. What a service declares at its top level is its API, read-only where it is state; what it keeps for itself sits in an object under an `id`, which no other file can reach. Sources without events (the outputs, plugins' `read` commands) are read on `refresh()`, which the menu calls as it opens. `Plugin` holds each plugin's one source (`watch`, `read`, `file`, through `CommandState`) and its IPC target.
- `ui/`: the kit ([Kit](docs/src/kit.md)). Widgets use it and the theme from `Config`, never raw colours or sizes.
- `builtins/`: the built-in names, one table each (`Statuses`, `Lists`, `States`, `Actions`): what a status shows and its fields, what a list holds and does, what lights a toggle, what an entry's `action` runs. Names are camelCase in every table.
- `widgets/`: the surfaces. `menu/` splits into `MenuModel` (levels, their bars and keys) and its view (`Menu`, `MenuHeader` with its `HeaderSlot`s and `HeaderItem`s for a bar, `MenuRow`, `MenuStatus`); `menu/calendar/` holds a calendar level (`CalendarModel`, `CalendarMonth`, `CalendarEvents`). A surface with state of its own keeps it in a `*Model`, the view only reading it.
- `plugins/`: the plugins the shell ships; `Plugin.qml` is their root, `PluginSettings.qml` their settings' root, `services/Plugins.qml` loads them. A plugin is a folder holding all of it: `<Name>.qml` (its state and actions, never drawing), `Settings.qml` (every setting it takes), and its views, listed in `views` and created with it, since a plugin folder is not a module the shell imports.
- `themes/`: the shipped colour presets, read through `ThemeFile.qml`.
- `menu.json`: the starter menu, shaped as a `config.json` so users can copy it.

The rest:

- `packages/calendar-sync/`: writes `calendar.file` from a list of calendars (vdirsyncer, khal); the shell never runs it.
- `packages/preview/`: runs a working tree in a nested niri (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `tests/`: the flake checks beyond the builds (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `modules/home-manager/quick-key/`: the module. `default.nix` runs the shell and writes `settings` as given to `config.json`, which must pass the shell's check as the configuration builds; `calendar-sync.nix` runs calendar-sync.

`Config.qml` is the schema of `config.json`: each key, its kind and its default. What a schema cannot say (an entry's fields, a name that must exist) is a check in `Validation.qml`, which the shell logs as it starts and `check.qml` fails on. Nothing else lists the settings or the built-in names.

## Code style

- Idiomatic Nix and QML. YAGNI. Read neighbouring files and match their patterns.
- A Repeater over a list that changes takes its length as `model`, each delegate reading its item by `index`, `?? ({})` since rows past a shrunk list's end read it before they go: an array model recreates every delegate on each change, dropping hover and wheel state.
- Nushell logic in a `script.nu`, wrapped by `writeNushellApplication` (`packages/builders.nix`).
- One-line `description` on every option, `defaultText` whenever a `default` references other config. Detail goes in a docs chapter.

## Comments

- Default to none. Comment only what the code can't say: the why, a non-obvious constraint, a cross-file pointer.
- One line, never two in a row (`tests/comments.nix` fails the check). Never restate code or repeat what the docs say.

## Writing style (docs, README)

- Plain declaratives, point first. No windup.
- No em-dashes.
- No LLM cadence: no "not just X but Y", no padded threes, no restating a point.
- Say it once. Cut every word the sentence survives without.

## Docs

- `nix build .#docs` builds the mdBook in `docs/`. Chapters in `docs/src/`, ordered by `SUMMARY.md`. `docs.nix` generates the reference: the settings as `Config.qml` declares them, then the module's options. Preview with `mdbook serve docs`.
- Chapters explain the model, never the options.
- Update the chapter in the same change as the behaviour.
