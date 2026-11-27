# Decisions

Settled with the owner up to v0.27.0-beta.5 (2026-11-24). A review round reads this first. An item here reopens only on new evidence from daily use (a bug, a measured cost), never on a new opinion; a finding that repeats one of these is dropped.

## Scope

- Personal use, 0.x, no stability promise. Major features are closed (README's Scope): a round looks for bugs, cuts and simplifications, never features.
- **Exception, 2026-11-25:** the owner opened one feature, the menu as a layout of islands (`menu.layout`, pinned levels, an entry's `layout`, `height`), for composability; designed over four review rounds (UX, architecture, config contract, correctness, Ask).
- After beta.5: weeks of daily use and a dated bug log before any review round.

## Settled

- **Notifications are a daemon's.** mako shows them; quick-key ships only do-not-disturb bells (`mako`, `dunst` plugins). The scripts that send a notification own its actions (`notify-send --action ... --wait`). The owner's keys: `Mod+N` the newest notification's actions in fuzzel, `Mod+Ctrl+N` dismiss, `Mod+D` do-not-disturb.
- **Ask keeps its shape.** A short answer shows above a level's input while the level redraws beneath; a long one, a table or an approval opens the panel. Two prototypes (the panel on every send; a split of level and top inputs) were tried and rejected: the original fit the common case.
- **Inputs stay on the levels they change** (Tasks, Calendar), plus the top catch-all. One input following every level was rejected: it puts an agent on levels it cannot change.
- **An input's `context`, not a `format`.** The conversation shows the text as typed; the context goes with every message, replies included, worded as where the text comes from.
- **How an agent behaves is the agent's config.** For Hermes over ACP: the assistant's tool set, `coding_context` off, a one-line platform hint; routing lives in its skills. quick-key sends no agent-specific wording, and never calendar titles as context (anyone who can invite the owner writes them).
- **Kept as they are:** Ask's `lines`, `placeholder`, `idle` and `promptGlyph`; `C-r` history; the default `notify`'s replace tag; `PluginSettings` ranges.
- **A notification's actions stay in fuzzel (`makoctl menu`)**, not a quick-key level: a level needs a source of notifications and their actions, the server just removed. Fuzzel's look is the dotfiles' to match. Delete needs no guard: it goes to the trash, sits last, and fuzzel needs it picked; rule 6's Shift is for what ends the session.
- **The do-not-disturb pop-up is its glyph alone.** The pop-up adds text only where a toggle's glyph does not change (keep awake); the bell is struck or not. A plugin's text would show in the bar too. No card is sent on a toggle.
- **A level never dims, an empty one says why.** Audio output's Apps stays reachable with no app playing and lists "No app playing sound", as Bluetooth off and Music with no player do; only actions dim. A paused app stays listed, so its volume can be set before it resumes. Loopbacks and filters are not apps (no `application.name`).
- **Status values are lowercase** ("off", "no song playing"), as values beside a label.
- **The minimalism round's outcome:** `menu.keysHint`, an entry's `legend`, the quieter defaults (no year, no single-layout status, no medium priority glyph), a key path closing the menu it opened.
- **The beta.7 round (2026-11-24):** a fix goes in only when measured and either common or a broken contract, or when it is a line or two; rare, low-impact or unmeasured findings are parked below. `every` and `pick` are cut (rule 3 holds under every setting; `/` filters every list). A plugin may not take a name the shell uses itself (`menu`, `drafts`, the built-ins); no prefix, which would break every binding. `theme.fontSize` stays whole; stylix's size is rounded. `notify` bodies are not escaped (rule 2: the command is the config's); mako's `markup` is the dotfiles'.
- **The layout of islands (2026-11-25):** a level has a layout (`menu.layout`, an entry's `layout`), listed top to bottom, the last against the edge; an entry without one opens in the current layout's `body` (the route rule), one with it replaces the layout until ESC. One `bar`, never focused, its slots and Ctrl keys holding still, only its left zone following focus (the slots half superseded on 2026-11-26, below); one `input`, showing the focused island's, whose visit ends on hide or a layout change, never on focus. A pin (`{ level = "t"; }`) leaves its level's rows; its `bar`, `layout`, `status` and `format` are refused. A pinned list's height is its `limit`, no paging; `height` N, the rows a body level holds at least, is for body levels. Focus by a pin's key or a click, ESC back to the body; a key path is the same pinned or not. Kit: `Stack` and `Island`, no focus model; one `MenuModel` with a `LevelModel` per island. Renames: `menu.header` → `menu.bar`, `menu.islands` → `menu.splitBar`.
- **Islands, settled after review (2026-11-25):** an island the layout lists holds its place between two that show; one with nothing shows empty there, and islands at either end stay out (amended 2026-11-27 from daily use: an empty bar under Wallpaper with `keysHint = false` should not be there; the body then meets the edge on such levels, the owner taking the move). A pinned level shows only on the level that pins it: it steps aside on every level opened from it and comes back with ESC; a pin below the top is declared in that level's own `layout` (option B, explicit over inherited).
- **Keys are data (2026-11-25, from daily use):** the islands on screen hold one key map, no key on two of them; a key goes to the island that shows it, wherever the cursor is (`keymap.js` builds the table per mode; `dispatch` is a lookup plus one handler per kind; `?`, the legends, `toggleEntry` and the check read it). Focus is only the cursor's island: arrows, `RET`, its input and legend; a pin's key, a click, `TAB` (the inputs on screen in turn, then the rows) or `↑↓` past an island's edge move it. The bar's left shows the actions and legend of the island with the cursor (minimal, after the owner found every island's crowded); `?` lists the actions of an island without the cursor. The check refuses two things on one key on one screen (one pinned list per level). Ctrl reaches the bar wherever the keys are.
- **RET runs the cursor's row, Shift rows included (2026-11-26, from daily use):** `S-RET` for capital rows failed silently on Power off; moving the cursor there is the deliberate step, as in any session menu, and Shift still guards the single keypress (`P`). No warning for open windows (out of scope). The owner's note on the rules: they guide, but bend where the user's deliberate choice and its acknowledged cost say so; a rule that makes a deliberate action fail silently is revisited, not defended.
- **The bar follows the cursor (2026-11-26, from daily use):** supersedes the layout entry's "never focused, its slots holding still"; its Ctrl half stands. The bar is the cursor island's bar, as the input is its input: its actions and legend, then its level's slots, so a pin's is its keys alone and a focused task's keys and legend read clearly, the clock and tray belonging to no focus or a scoped one (the owner). What it draws follows the cursor, its keys never: Ctrl reaches the body's level's bar wherever the cursor is, so muscle memory holds. It is empty only while every island the cursor may be on has nothing for it, so moving never adds or removes it. The cursor may stand on the bar (owner: "navigate down to the clock, and the remaining icons"): a flag beside the island with the cursor, whose bar it stays; its stops are what a click runs and the bar draws (`Statuses.shown`, one decision for both), actions first; `←→` only where no row on screen binds them, so a volume pair keeps them (the owner's choice); `RET` the click, `M-RET` the item's own menu; `ESC` back to its island, and back from a level it opened, onto its stop. The flag is `cursorOnBar`: QML takes `onBar` for a signal handler, its binding never evaluating.
- **Kept after the beta.7 round:** Daemons (Quickshell's PowerProfiles cannot tell a daemon is running); calendar-sync over home-manager's calendar accounts (its vdirsyncer service never runs `discover`, names no failed calendar, needs a rebuild per edit); niriMinimap; Qt's GPU renderer (the software one may drop the tray's tint and the conversation's fade).
- **A task's id is its title** (calendar-sync), todoman's number only between two listed tasks of one title, which a tick refuses and which renumber as their files change. A tick acts on the one task of its title, whatever id it carries. No todoman cache or private schema: only its CLI and porcelain output. A task keeps at most one tick running and one queued, a press taking back the queued one: writes merge, no debounce.
- **The resource budget, measured 2026-11-24:** start +81 ms over bare Quickshell, idle CPU 0, no leak over 400 opens. Memory is 35-38 MB anon before the first surface and 65-75 MB (starter) or about 80 MB (the owner's config) after it, Mesa's GL context being most of the step (the software renderer stays at 28 MB); `systemctl status`'s Memory figure is lower as it lists swap apart.

## Not doing

- An own notification server again, in any form: rules adding actions, inline reply, a history view, a Notifications level, a quick-key menu over mako.
- Ask: a top-right card, panel-only, a slash-command picker, form elicitation, terminal auth, level rows as context. Agent-started conversations wait until needed (then: a `resume <sessionId>` IPC call and a notification action, about 5 lines).
- Structured write paths for the owner's adds: khal's and todoman's date parsing fail on Portuguese. `input.cmd` stays for those who have one.
- Recordings: "Copy smaller" (WhatsApp compresses).
- calendar-sync: `SEQUENCE` (scheduling only), keeping an in-progress percentage on reopen, cancelled tasks.
- D5, fields' `opens`/`does` flags: kept locally as `refs/archive/trim-d5-opens`.
- Deferred features, out until the owner asks: battery time left, week numbers, per-event reminders, muting an app, a device-switch pill, mic in use, every backlight as a list, letters by scan code. Skipped for good: grouping notifications by app, frecency, diff-based reload, async thumbnails, a `due:` shortcut.

## Parked

Found in the beta.7 round, real but rare or low impact; reopen on a sighting in daily use.

- Hover taking the cursor (N6): dropped, as Qt re-delivers a hover under a still pointer and it stole the row `ESC` had restored; a form that moves only on pointer motion needs a position compare, two highlights meanwhile.
- The pop-up's tone ignores a plugin's `phase` (Osd.qml:72); folding it into `Statuses.of` would add pop-ups on error.
- `themes.<name>` colours typed `str` in the module (warns at runtime, where `settings.theme` fails the build); a misspelt colour name in a theme file is ignored silently.
- Calendar steps cost more CPU with hundreds of events (854: 42 ms a day step, 88 ms a month); key repeat slows itself and nothing lags after release.
- A task titled with a bare number can share its id with one of two same-titled tasks todoman numbers so.
- Text-only rows start their label in the icon column, as an app menu's rows do.
- `times()` in CalendarEvents decides in a view; CalendarMonth's Repeater takes the array (no visible effect).
- A bar tip cut at the screen's edge when the menu spans the screen.
- Suite's timeout counts polls, not time; no positive control for the "never runs" cases; no guard on two `.js` libraries of one name.
- A `width` on a row that is no level passes the check and does nothing.
- An ACP session id starting with `-` reaches `open` as a flag (needs a hostile adapter).
- `notify-send` bodies carry untrusted text into mako's Pango markup (cosmetic, unseen).
- Qt's `textinput` warning, twice per close; silencing the category could hide real ones.
- KeyList's rows (Ask's keys) wash on hover though a click does nothing.

From the review before a week of use (2026-11-26, beta.18; navigation, design and config each 8/10):

- `TAB` while filtering types a tab into the query (A4).
- `0` from the body steps back to the body, not the pin, which menu.md implies (A5).
- Holding Ctrl listed no bar keys under wtype in the preview (A6); unconfirmed on a real keyboard.
- Which island has the cursor shows only in the input's placeholder and the bar (A8).
- Bluetooth says off twice, glyph and text (B4); English day names beside a localised date (B7).
- README's pitch and a tour at its top (B6): after the week.
- `desc`/`label` and `icon`/`glyph` name one thing twice (C4): renaming churns every config.
- `input.plugin` may name a plugin that takes no text (C10): the check cannot know.
- Null-default settings show kind "any" in the reference: a declared kind needs a table.
- The owner's Tasks `c` (Done, persisted) sits one modifier from `C-c` Calendar and acts unseen at the top (A7): the owner's config, not the shell's.

## Open

- Ask's cost: about 17% of the shell's lines and 25% of commits since 2026-11-13 (80 of 346 since 11-20). Its shape is settled; if the churn stays above the core's after the bug-log weeks, consider moving it out as a user plugin (needs rule 12 amended).

- The owner, at the desk: paste a copied recording into WhatsApp; add from the real menu.
- A plugin's `file` source can miss a write: a file rewritten with `>` is read while truncated (text ""), and the write that follows is never read, as Quickshell's FileView skips a reload while a read runs (fileview.cpp:302). Seen as the menu suite's last flake, about 1 in 50 runs at 16 at once, after the beta.7 round fixed the tests' own (cases acting inside `until`). Measured 2026-11-24: single writes and renames 30 ms apart missed none; five in-place writes microseconds apart left 23 to 85 of 100 runs on the wrong content. calendar-sync renames, so it is safe; plugins.md tells a writer to rename. Unseen in daily use; a re-read after each change would cover the rest.
- Watch: todoman 4.7 logs a traceback on two CATEGORIES lines (todoman's).
- Reminders are plain notifications; a script with Snooze and Open link if the owner wants it.
- The tray draws Solaar's icon (`battery-090`, an Ayatana item with no pixmap) as a missing-image checkerboard, though the icon resolves in Quickshell outside the tray; seen since 2026-11-18, not yet traced (Quickshell's tray or Solaar).
- Audio output's Apps: two streams of one app (two browser tabs) show alike, as a row names only the app; telling them apart would show `media.name`, the owner's call. Moving an app to another device stays with pavucontrol.
