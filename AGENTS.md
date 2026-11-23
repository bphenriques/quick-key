# Agent Instructions

A Quickshell menu and its home-manager module. What it does is in [README.md](./README.md) and the docs. This file is the rules.

## Design rules

Every change follows these; a change that cannot is a reason to revisit the rule here first, not to work around it.

**Defaults are the suggested setup, not a ceiling.** The rules bind the code and the defaults. A setting may depart from a rule of look or layout (4, 9, 13) when a user opts in, within limits: the check bounds each value (a range, a choice) and the layout clamps what it cannot see (a size to the screen). Unset, nothing changes. Rules 1 to 3, 7, 8, 10 to 12 and `Label`'s plain text hold under every setting.

1. **Data, not code.** What the menu shows and does comes from `menu.entries`. QML has no case for a particular entry, tool or device; a new need becomes a setting in `Config.qml`, with a check in `Validation.qml` when it can be wrong. A built-in (status, list, state, action, view) is one entry in its table, never a `case` or name test elsewhere.
2. **Tools through the config.** QML runs nothing by name; the config that owns a tool sets its command. A default may name only a standard tool (`busctl`, `notify-send`, Wayland's `wl-paste`) or, in a plugin named after a tool, that tool: listing the plugin is choosing it. The shell reads only output it defines (the state line), never a tool's own format. The compositor is reached only through `Compositor` (see [Compositor](docs/src/compositor.md)). The one exception: a link opens with the desktop's handler for links.
3. **Events over polling.** What has no events is read when the menu opens.
4. **Layout is declared.** A level is its body past an optional bar, at one edge of the screen, and holds still while open: its width and columns come from its entry, never from what it shows. Where a surface sits (its edge, alignment, margin) is a setting, and every surface stays within its screen. The menu and a plugin's panel share one frame, `Panel`; the notifications' stack, the one surface outside it, takes the keys where its cards already are, its bar where its pills sit; one open at a time (`Panels`). An input's text is the working area and the level's redraw the proof. An agent's input sits on a level showing what it changes, or at the top as the catch-all: never one per level, and an input never filters (see [Menu](docs/src/menu.md)).
5. **Order is explicit.** Top level by `lib.mkOrder`, rows pairing related things. Within a level, the list order, paired for the row it shares.
6. **Labels.** Sentence case; the one ellipsis (`Words`) when a row opens a picker or an app, and on what is under way or waits on you. A row's label is its `desc` and never changes; what its status reports sits on its right (rule 8). A bar holds content, never a title, except an app's own menu, which no entry names and so names itself there. Every row of a level carries an icon; `space` is only ever a picker; what ends the session takes Shift (see [Menu](docs/src/menu.md)).
7. **Keys hold still.** Letters are actions and digits are list items; a bar letter is taken with Ctrl, and the modifiers compose. A key path (`a 2`) is what a binding runs (`menu press`, or `<plugin> press` on a surface of its own), so a binding never drifts from what it shows; filtering is the one place digits follow the rows shown. `ESC` is the one way back: it never moves the keys, stops or answers anything (see [Menu](docs/src/menu.md#keys)).
8. **State is visible.** The menu shows state, the OSD shows changes. A row's status and a listed item's detail sit on its right as data, values in a column; an action's value, alone in reporting, follows its label instead. Tone goes to what reports, never to a label beside it, and colour is never all that says so. What cannot run now dims; what can never run here is not declared (see [Menu](docs/src/menu.md)).
9. **Text is plain, in one font.** Text is one size, but a title (the bar's clock, a card's summary) a setting may scale, at most 1.5 times; unset, sizes in pixels follow the font. What stands out does so by tone, weight and space; keys are told by their tone, so they stay regular. Bold (`strong`) is what to find first. Everything renders through `Label`, which never interprets markup: titles from apps and streams are untrusted. An agent's answer is the one exception: `Markup` renders its Markdown in the menu's terms, fetching nothing, running no HTML (see [Kit](docs/src/kit.md)).
10. **Done means seen working.** A change is tested where it runs (see [DEVELOPMENT.md](DEVELOPMENT.md)), not only evaluated.
11. **Widgets compose the kit.** Colour and dimming come from a `tone`, glyphs from `Icon`, the wheel from `WheelSteps`, sizes from `Metrics`, outlines and dividers from `Surface`, `Pill` and `Divider`, emphasis from `Label`'s `strong`, keyboard surfaces from `Panel`, shared words from `Words`, and dates and times from `Clock` (see [Kit](docs/src/kit.md)). A widget never sets opacity to dim, picks a theme colour or size itself, or draws a glyph as text.
12. **The core is what every desktop has.** Audio, network, Bluetooth, power, outputs and backlight, tray, music, the calendar. Anything tied to one tool or taste is a plugin: off until listed, reaching the shell only through its API (see [Plugins](docs/src/plugins.md)), and held to these rules like the core, keyboard first and built from the kit. The conversation UI is part of the kit: a plugin that talks builds on it, and one with a single consumer is still the kit's.
13. **Motion confirms, never delays.** Surfaces fade in and out, or slide from their edge where a setting asks, colours ease, all over `theme.animationDuration` (`0` for none) and through the kit (`Fade`, `Label`, `Icon`), never a widget's own; a highlight follows the pointer at once, as easing trails it. Nothing waits on an animation and nothing moves or resizes while open: a key acts at once, the menu appears and closes at once, and opening the conversation is a change of surface, as opening a level is; a stack of pop-ups reflows, unanimated, as one comes or goes.

## Layout

The shell, under `packages/quick-key/`:

- `services/`: state read from its source (D-Bus, Pipewire, niri, commands), pushed by events. What a service declares at its top level is its API, read-only where it is state; what it keeps for itself sits in an object under an `id`, which no other file can reach. Sources without events (the outputs, plugins' `read` commands) are read on `refresh()`, which the menu calls as it opens. `Plugin` holds each plugin's one source (`watch`, `read`, `file`, through `CommandState`) and its IPC target.
- `ui/`: the kit ([Kit](docs/src/kit.md)). Widgets use it and the theme from `Config`, never raw colours or sizes.
- `builtins/`: the built-in names, one table each (`Statuses`, `Lists`, `States`, `Actions`, `Views`): what a status shows and its fields, what a list holds and does, what lights a toggle, what an entry's `action` runs (else the action of that name of the plugin its level lists), what a level's `view` shows and the keys it takes. Names are camelCase in every table.
- `widgets/`: the surfaces. `menu/` splits into `MenuModel` (levels, their bars and keys), with `InputModel` for a level's input, and its view (`Menu`, `Island` for the input, `MenuHeader` with its `HeaderSlot`s and `HeaderItem`s for a bar, `MenuRow`, `MenuStatus`); `menu/calendar/` holds a calendar level (`CalendarModel`, `CalendarMonth`, `CalendarEvents`). `ListFilter` filters a level's list in place. A surface with state of its own keeps it in a `*Model`, the view only reading it.
- `plugins/`: the plugins the shell ships; `Plugin.qml` is their root, `PluginSettings.qml` their settings' root, `services/Plugins.qml` loads them. A plugin is a folder holding all of it: `<Name>.qml` (its state and actions, never drawing), `Settings.qml` (every setting it takes), and its views, listed in `views` and created with it, since a plugin folder is not a module the shell imports.
- `themes/`: the shipped colour presets, read through `ThemeFile.qml`.
- `menu.json`: the starter menu, shaped as a `config.json` so users can copy it.

The rest:

- `packages/calendar-sync/`: writes `calendar.file` from a list of calendars (vdirsyncer, khal); the shell never runs it.
- `packages/preview/`: runs a working tree in a nested niri (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `tests/`: the flake checks beyond the builds (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `modules/home-manager/quick-key/`: the module. `default.nix` runs the shell and writes `settings` as given to `config.json`, which must pass the shell's check as the configuration builds; `calendar-sync.nix` runs calendar-sync.

`Config.qml` is the schema of `config.json`: each key, its kind and its default. What a schema cannot say (an entry's fields, a name that must exist) is a check in `Validation.qml`, which the shell logs as it starts and `check.qml` fails on; an entry's fields are a table there (`fields`), only what spans fields written out. A renamed key adds its line to `Config.renamed`, so a config from before says what to write instead. Nothing else lists the settings or the built-in names.

## Code style

- Idiomatic Nix and QML. YAGNI. Read neighbouring files and match their patterns.
- A Repeater over a list that changes never takes the array itself, which recreates every delegate on each change, dropping hover and wheel state. Items with an identity (a bar's items, tray icons) take a `ScriptModel` keyed by it (`objectProp`), so each delegate follows its item. Slots by position (a level's numbered rows) take the length, each delegate reading its item by `index`, `?? ({})` since rows past a shrunk list's end read it before they go; a small bound that comes and goes often (the notifications' `limit`) takes the bound, hiding delegates past its end. A list that changes many times a second, each item costly to draw (a streaming answer's pieces), keeps a `ListModel` in step instead, so only the item that changed is told (`Markdown`).
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
