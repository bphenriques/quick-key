# Agent Instructions

A Quickshell menu and its home-manager module. What it does is in [README.md](./README.md) and the docs. This file is the rules.

## Design rules

Every change follows these; a change that cannot is a reason to revisit the rule here first, not to work around it.

1. **Data, not code.** What the menu shows and does comes from `menu.entries`. QML has no case for a particular entry, tool or device; a new need becomes an option in `settings.nix`, with an assertion when it can be wrong.
2. **Tools through the config.** QML runs nothing by name. The config that owns a tool sets its command, and a default may name only a standard tool (`wpctl`, `systemd-inhibit`). The shell reads only output it defines (the state line, see [Sources](docs/src/plugins.md#sources)), never a tool's own format. What needs more of one tool is a plugin. The compositor is reached only through `Compositor` (see [Compositor](docs/src/compositor.md)). The one exception: a link opens with the desktop's handler for links.
3. **Events over polling.** What has no events is read when the menu opens; what must sample (the mic level) runs only while shown.
4. **Layout is declared.** A level's columns and width come from its entry (`columns`, `width`, else `menu.columns`, `menu.width`), never measured from what it shows, so it holds still; entries flow across, so order decides neighbours. Make the menu wider before adding columns or truncating.
5. **Order is explicit.** Top level by `lib.mkOrder`, rows pairing related things. Within a level, the list order, paired for the row it shares.
6. **Labels.** Sentence case; `...` when it opens a picker or an app; a pair named for what it changes (`Volume`, `Track`). Device levels put Power on `p` and Configure... on `c`; every action in a level carries an icon; `space` is only ever a picker. What ends the session takes Shift (Reboot, Shutdown).
7. **Keys hold still.** Letters are actions, digits are list items, Ctrl+digit an item's own menu, which keeps letters from the labels its app supplies. A key may carry Ctrl or Alt in its name (`Ctrl+Left`, as niri writes bindings); hints show keys Emacs-style, `C-` Ctrl, `M-` Alt, `s-` Super, Shift as the capital letter (`C-←→`, `s-k`), symbols for the arrows, `DEL` for Backspace and `ESC` for Escape as Emacs writes them; a modifier never runs the plain key, Shift only picks the capital letter, and Super stays the compositor's. Pinned items keep their digit and dim while absent, and their label names them wherever the menu shows them; the rest follow by name (internal audio first), never by signal or recency.
8. **State is visible.** The menu shows state, the OSD shows changes; a level that lists its items shows only its state in the header. A listed item in use and a toggle that is on (`activeWhen`) take the `primary` tone; the right of a row holds data (battery, signal), never a word for that state. A top-level status names its state only when it has no value to show (`off`, `muted`, `paused`). What cannot run right now dims, so keys hold still; what can never run on this machine is not declared.
9. **Text is plain.** Everything renders through `Label`, which never interprets markup: titles from apps and streams are untrusted. The one source-specific case in the core is next to it: Music reads song and artist out of the XML some radio streams (Bauer Media) send as their title, since MPRIS leaves no glue to do it in.
10. **Done means seen working.** A change is tested where it runs (see [DEVELOPMENT.md](DEVELOPMENT.md)), not only evaluated.
11. **Widgets compose the kit.** Colour and dimming come from a `tone`, glyphs go through `Icon`, the wheel through `WheelSteps`, a colour that is data (a calendar's) through `Swatch`, a size in characters or lines through `Metrics`; a widget never sets opacity to dim, picks a theme colour itself, or draws a glyph as text.
12. **The core is what every desktop has.** Audio, network, Bluetooth, power, outputs and backlight, tray, music, the calendar. Anything tied to one tool or taste is a plugin: off until listed, reaching the shell only through its API (see [Plugins](docs/src/plugins.md)), and held to these rules like the core, keyboard first and built from the kit.
13. **Motion confirms, never delays.** Surfaces fade in and out, colours ease, all over `theme.animationDuration` (`0` for none) and through the kit (`Fade`, `Label`, `Icon`, `ListItem`), never a widget's own. Nothing waits on an animation: a key acts at once, the menu appears and closes at once (its background blur cannot fade with it, and a fade-out would hold the keyboard), and nothing moves or resizes.

## Layout

The shell, under `packages/quick-key/`:

- `services/`: state read from its source (D-Bus, Pipewire, niri, commands), pushed by events. What a service declares at its top level is its API, read-only where it is state; what it keeps for itself sits in an object under an `id`, which no other file can reach. Sources without events (the outputs, plugins' `read` commands) are read on `refresh()`, which the menu calls as it opens. `Plugin` holds each plugin's one source (`watch`, `read`, `file`, through `CommandState`) and its IPC target.
- `ui/`: the kit ([Kit](docs/src/kit.md)). Widgets use it and the theme from `Config`, never raw colours or sizes.
- `widgets/`: the surfaces. `menu/` splits into `MenuModel` (state, keys) and `Menu`, `MenuStatus` (view).
- `plugins/`: the plugins the shell ships; `Plugin.qml` is their root, `services/Plugins.qml` loads them.
- `themes/`: the shipped colour presets, read through `ThemeFile.qml`.
- `menu.json`: the starter menu, shaped as a `config.json` so users can copy it.

The rest:

- `packages/calendar-sync/`: writes `calendar.file` from a list of calendars (vdirsyncer, khal); the shell never runs it.
- `packages/preview/`: runs a working tree in a nested niri (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `tests/`: the flake checks beyond the builds (see [DEVELOPMENT.md](DEVELOPMENT.md)).
- `modules/home-manager/quick-key/`: the module. `default.nix` runs the shell, `settings.nix` is the schema of `config.json` and its assertions, `calendar-sync.nix` runs calendar-sync.

`settings.nix` mirrors `Config.qml`: one option per key, unset by default so `Config.qml`'s default applies. Change both together. A key holding a map or list with a default is an `opt`, never a `group`: an unset group is written as `{}`, which replaces the default.

## Code style

- Idiomatic Nix and QML. YAGNI. Read neighbouring files and match their patterns.
- Nushell logic in a `script.nu`, wrapped by `writeNushellApplication` (`packages/builders.nix`).
- One-line `description` on every option, `defaultText` whenever a `default` references other config. Detail goes in a docs chapter.

## Comments

- Default to none. Comment only what the code can't say: the why, a non-obvious constraint, a cross-file pointer.
- One line. Never restate code or repeat what the docs say.

## Writing style (docs, README)

- Plain declaratives, point first. No windup.
- No em-dashes.
- No LLM cadence: no "not just X but Y", no padded threes, no restating a point.
- Say it once. Cut every word the sentence survives without.

## Docs

- `nix build .#docs` builds the mdBook in `docs/`. Chapters in `docs/src/`, ordered by `SUMMARY.md`. `docs.nix` injects the options reference. Preview with `mdbook serve docs`.
- Chapters explain the model, never the options.
- Update the chapter in the same change as the behaviour.
