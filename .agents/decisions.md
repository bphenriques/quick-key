# Decisions

Settled with the owner up to v0.27.0-beta.5 (2026-11-24). A review round reads this first. An item here reopens only on new evidence from daily use (a bug, a measured cost), never on a new opinion; a finding that repeats one of these is dropped.

## Scope

- Personal use, 0.x, no stability promise. Major features are closed (README's Scope): a round looks for bugs, cuts and simplifications, never features.
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

## Not doing

- An own notification server again, in any form: rules adding actions, inline reply, a history view, a Notifications level, a quick-key menu over mako.
- Ask: a top-right card, panel-only, a slash-command picker, form elicitation, terminal auth, level rows as context. Agent-started conversations wait until needed (then: a `resume <sessionId>` IPC call and a notification action, about 5 lines).
- Structured write paths for the owner's adds: khal's and todoman's date parsing fail on Portuguese. `input.cmd` stays for those who have one.
- Recordings: "Copy smaller" (WhatsApp compresses).
- calendar-sync: `SEQUENCE` (scheduling only), keeping an in-progress percentage on reopen, cancelled tasks.
- D5, fields' `opens`/`does` flags: kept locally as `refs/archive/trim-d5-opens`.
- Deferred features, out until the owner asks: battery time left, week numbers, per-event reminders, muting an app, a device-switch pill, mic in use, every backlight as a list, letters by scan code. Skipped for good: grouping notifications by app, frecency, diff-based reload, async thumbnails, a `due:` shortcut.

## Open

- The owner, at the desk: paste a copied recording into WhatsApp; add from the real menu.
- Watch: the menu suite's "an input's key gives it the keys" failed once in about 20 runs; todoman 4.7 logs a traceback on two CATEGORIES lines (todoman's).
- Reminders are plain notifications; a script with Snooze and Open link if the owner wants it.
- The tray draws Solaar's icon (`battery-090`, an Ayatana item with no pixmap) as a missing-image checkerboard, though the icon resolves in Quickshell outside the tray; seen since 2026-11-18, not yet traced (Quickshell's tray or Solaar).
- Audio output's Apps: two streams of one app (two browser tabs) show alike, as a row names only the app; telling them apart would show `media.name`, the owner's call. Moving an app to another device stays with pavucontrol.
