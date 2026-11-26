# Agent Instructions

A Quickshell menu and its home-manager module. What it does is in [README.md](./README.md) and the docs. This file is the rules.

## Design rules

Every change follows these; a change that cannot is a reason to revisit the rule here first, not to work around it.

**Defaults are the suggested setup, not a ceiling.** The rules bind the code, the starter and the defaults, which promote them; the docs and recipes show them. A user's config is theirs: it may break a rule of look, layout, labels or order, and the shell draws it as written. Each value stays within its check's bounds, and the layout clamps what it cannot see (a size to the screen). The check rejects only what cannot work: a value of the wrong kind or out of range, a name that does not exist, two things on one key or a key the menu keeps, a field where it does nothing, a command ending in an operator. No setting polls (3), moves a key from what it shows or ESC from going back (7), or renders markup (`Label`).

1. **Data, not code.** What the menu shows and does comes from `menu.entries`. QML has no case for a particular entry, tool or device; a new need becomes a setting in `Config.qml`, with a check in `Validation.qml` when a wrong value would conflict, name nothing, or break. A built-in (status, list, state, action, view) is one entry in its table, never a `case` or name test elsewhere; a key is a binding in `keymap.js`'s table, never a `case` in the router.
2. **Tools through the config.** QML runs nothing by name; the config that owns a tool sets its command. A default may name only a standard tool (`busctl`, `notify-send`, Wayland's `wl-paste`) or, in a plugin named after a tool, that tool: listing the plugin is choosing it. The shell reads only output it defines (the state line), never a tool's own format. The compositor is reached only through `Compositor` (see [Compositor](docs/src/compositor.md)).
3. **Events over polling.** What has no events is read when the menu opens.
4. **Layout is declared.** The menu is a stack of islands at the bottom of the screen, centred, listed top to bottom in `menu.layout`, the last against the edge: `input`, `body` (where levels draw, once), `bar` (one, never focused, only its left zone following the cursor) and pinned levels (`{ level = "t"; }`). A level opens in the current layout's body unless its entry declares a `layout`, which holds until `ESC`; a pinned level shows only on the level that pins it. A layout's islands stack up from the edge and hold their places while open: one that has nothing shows empty, and only islands at the far end may stay out, since nothing lies beyond them. An island's width, columns and height come from its config (`width`, `columns`, `limit`, `height`), never from what it shows. The pop-up sits at the right edge; the one margin from the screen's edge (`theme.edgeMargin`) is a setting, and every surface stays within its screen, the body cut first. The menu and a plugin's panel are each a kit `Stack`; one open at a time (`Panels`). An input's text is the working area and the level's redraw the proof. An agent's input sits on a level showing what it changes, or at the top as the catch-all: one input island, showing the input of the island with the cursor, and an input never filters (see [Menu](docs/src/menu.md)).
5. **Order is explicit.** Top level by `lib.mkOrder`, rows pairing related things. Within a level, the list order, paired for the row it shares.
6. **Labels.** Sentence case; the one ellipsis (`Words`) when a row opens a picker or an app, and on what is under way or waits on you. A row's label is its `desc` and never changes; what its status reports sits on its right (rule 8). A bar holds content, never a title, except an app's own menu, which no entry names and so names itself there. Every row of a level carries an icon; what ends the session takes Shift (see [Menu](docs/src/menu.md)).
7. **Keys hold still.** The islands on screen hold one key map, no key on two of them: a key goes to the island that shows it, wherever the cursor is. Letters are actions and digits are list items. One island has the cursor, given by a pinned level's key on the level that pins it, a click, `TAB` (each input on screen in turn, then the rows) or an arrow past its first or last row onto the island beside; on a level whose entries leave an arrow pair free, the arrows move it over its rows as laid out, which `RET` runs, never changing what a digit picks. A bar letter is taken with Ctrl wherever the cursor is, and the modifiers compose. A key path (`a 2`) is what a binding runs (`menu press`, or `<plugin> press` on a surface of its own), the same whether its entry is pinned or opened, never through the cursor, so a binding never drifts from what it shows; filtering is the one place digits follow the rows shown. `ESC` is the one way back: it leaves an input for its island, an island for the body, else steps back, and never stops or answers anything (see [Menu](docs/src/menu.md#keys)).
8. **State is visible.** The menu shows state, the OSD shows changes. A row's status and a listed item's detail sit on its right as data, values in a column; an action's value, alone in reporting, follows its label instead. Tone goes to what reports, never to a label beside it, and colour is never all that says so. What cannot run now dims; what can never run here is not declared (see [Menu](docs/src/menu.md)).
9. **Text is plain, in one font.** Text is one size; sizes in pixels left unset follow the font. What stands out does so by tone, weight and space; keys are told by their tone, so they stay regular. Bold (`strong`) is what to find first. Everything renders through `Label`, which never interprets markup: titles from apps and streams are untrusted. An agent's answer is the one exception: `Markup` renders its Markdown in the menu's terms, fetching nothing, running no HTML (see [Kit](docs/src/kit.md)).
10. **Done means seen working.** A change is tested where it runs (see [DEVELOPMENT.md](DEVELOPMENT.md)), not only evaluated.
11. **Widgets compose the kit.** Colour and dimming come from a `tone`, glyphs from `Icon`, the wheel from `WheelSteps`, sizes from `Metrics`, outlines and dividers from `Surface`, `Pill` and `Divider`, emphasis from `Label`'s `strong`, keyboard surfaces from `Stack` and `Island`, shared words from `Words`, and dates and times from `Clock` (see [Kit](docs/src/kit.md)). A widget never sets opacity to dim, picks a theme colour or size itself, or draws a glyph as text.
12. **The core is what every desktop has.** Audio, network, Bluetooth, power, outputs and backlight, tray, music, the calendar. Anything tied to one tool or taste is a plugin: off until listed, reaching the shell only through its API (see [Plugins](docs/src/plugins.md)), and held to these rules like the core, keyboard first and built from the kit. The conversation UI is part of the kit: a plugin that talks builds on it, and one with a single consumer is still the kit's.
13. **Motion confirms, never delays.** Surfaces fade in and out, colours ease, all over `theme.animationDuration` (`0` for none) and through the kit (`Fade`, `Label`, `Icon`), never a widget's own; a highlight follows the pointer at once, as easing trails it. Nothing waits on an animation and nothing moves or resizes while open: a key acts at once, the menu appears and closes at once, and opening the conversation is a change of surface, as opening a level is.

## Layout

The shell, under `packages/quick-key/`:

- `services/`: state read from its source (D-Bus, Pipewire, niri, commands), pushed by events. What a service declares at its top level is its API, read-only where it is state; what it keeps for itself sits in an object under an `id`, which no other file can reach. Sources without events (the outputs, plugins' `read` commands) are read on `refresh()`, which the menu calls as it opens. Decisions a service makes given the time sit in a pure `.js` library beside it (`clock.js`, `calendar.js`). `Plugin` holds each plugin's one source (`watch`, `read`, `file`, through `CommandState`) and its IPC target.
- `ui/`: the kit ([Kit](docs/src/kit.md)), its conversation pieces in `ui/conversation/` (`qs.ui.conversation`). Widgets use it and the theme from `Config`, never raw colours or sizes.
- `builtins/`: the built-in names, one table each (`Statuses`, `Lists`, `States`, `Actions`, `Views`): what a status shows and its fields, what a list holds and does, what lights a toggle, what an entry's `action` runs (else the action of that name of the plugin its level lists), what a level's `view` shows and the keys it takes. Names are camelCase in every table.
- `widgets/`: the surfaces. `menu/` splits into `MenuModel` (levels, the layout and which island has the cursor, the bar's slots, the one input, and the key map `keymap.js` builds per mode, which `dispatch` routes), a `LevelModel` per island (what a level shows and does: items, rows, cursor, filter, legend), with `InputModel` for the input, and its view (`Menu`, `MenuBody` for a level's rows, `MenuInput` for the input, `MenuHeader` with its `HeaderSlot`s and `HeaderItem`s for a bar, `MenuRow`, `MenuStatus`); `menu/calendar/` holds a calendar level (`CalendarModel`, `CalendarMonth`, `CalendarEvents`), drawn by `CalendarView` beside `Menu`, as `Views` names them. `ListFilter` filters a level's list in place. A surface with state of its own keeps it in a `*Model`, the view only reading it and calling its functions: state is written in one place, the model or the plugin that owns it (`check.sh` fails a view that writes it).
- `plugins/`: the plugins the shell ships; `Plugin.qml` is their root, `PluginSettings.qml` their settings' root, `services/Plugins.qml` loads them. A plugin is a folder holding all of it: `<Name>.qml` (its state and actions, never drawing), `Settings.qml` (every setting it takes), and its views, listed in `views` and created with it, since a plugin folder is not a module the shell imports; a type of its own it uses by name is listed in a `qmldir` beside it (Ask's `Acp`), and its pure decisions sit in a `.js` library beside it (`exchanges.js`).
- `themes/`: the shipped colour presets, read through `ThemeFile.qml`.
- `menu.json`: the starter menu, shaped as a `config.json` so users can copy it.

The rest:

- `packages/calendar-sync/`: writes `calendar.file` from a list of calendars (vdirsyncer, khal); the shell never runs it.
- `packages/preview/`: runs a working tree in a nested niri (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `tests/`: the flake checks beyond the builds (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `modules/home-manager/quick-key/`: the module. `default.nix` runs the shell and writes `settings` as given to `config.json`, which must pass the shell's check as the configuration builds; `calendar-sync.nix` runs calendar-sync.

`Config.qml` is the schema of `config.json`: each key, its kind and its default. What a schema cannot say (an entry's fields, a name that must exist) is a check in `Validation.qml`, which the shell logs as it starts and `check.qml` fails on; an entry's fields are a table there (`fields`), only what spans fields written out. A check is for a conflict or an error, never taste; the starter, docs and recipes promote the rules. A renamed key adds its line to `Config.renamed`, a renamed entry field to `Validation.renamedFields`, so a config from before says what to write instead, until the next release that is not a beta. Nothing else lists the settings or the built-in names.

## Code style

- Idiomatic Nix and QML. YAGNI. Read neighbouring files and match their patterns.
- A Repeater over a list that changes never takes the array itself, which recreates every delegate on each change, dropping hover and wheel state. Items with an identity (a bar's items, tray icons) take a `ScriptModel` keyed by it (`objectProp`), so each delegate follows its item. Slots by position (a level's numbered rows) take the length, each delegate reading its item by `index`, `?? ({})` since rows past a shrunk list's end read it before they go. A list that changes many times a second, each item costly to draw (a streaming answer's pieces), keeps a `ListModel` in step instead, so only the item that changed is told (`Markdown`).
- A decision worth a unit case goes in a `.js` library beside its QML file, given what it reads, `now` included; the QML keeps thin wrappers. Library names are unique across the shell, as the unit check copies them into one folder.
- Nushell logic in a `script.nu`, wrapped by `writeNushellApplication` (`packages/builders.nix`).
- One-line `description` on every option, `defaultText` whenever a `default` references other config. Detail goes in a docs chapter.

## Comments

- Default to none. Comment only what the code can't say: the why, a non-obvious constraint, a cross-file pointer.
- One line by default. A contract the code cannot show (a table's fields, a protocol's steps) may take a short block of up to four lines; `tests/comments.nix` fails a longer one. Never restate code or repeat what the docs say.

## Commits

- One purpose per commit. The subject says what changed in under 72 characters; the body says why.
- Only the owner edits this file.

## Writing style (docs, README)

- Plain declaratives, point first. No windup.
- No em-dashes.
- No LLM cadence: no "not just X but Y", no padded threes, no restating a point.
- Say it once. Cut every word the sentence survives without.

## Docs

- `nix build .#docs` builds the mdBook in `docs/`. Chapters in `docs/src/`, ordered by `SUMMARY.md`. `docs.nix` generates the reference by running `docs/reference.qml` in the shell, headless: the settings, an entry's fields and the built-in names as the shell declares them, each described by the comment above it, then the module's options. A setting or field without a comment shows none there. Preview with `mdbook serve docs`.
- Chapters explain the model, never the options.
- Update the chapter in the same change as the behaviour.
