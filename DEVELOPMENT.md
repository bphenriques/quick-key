```bash
nix fmt                     # format + lint (treefmt)
nix flake check -L          # formatting, package builds (check.sh included) and tests
nix build .#docs            # docs site → result/index.html
```

`packages/quick-key/check.sh` holds the design rules in [AGENTS.md](AGENTS.md) that a text search can check, each under a comment naming its rule, and every build runs it.

`tests/` holds the flake checks beyond the builds, listed in `tests/default.nix`: `module-eval` (what the module writes into `config.json`, and that the build fails on a setting the check rejects) and `qml-<concern>` (the shell's logic in a real Quickshell, headless, one check per folder of `tests/qml/`: its `shell.qml` holds the cases, a TAP line each, and the rest of the folder is the config they run against), `unit` (pure logic in qmltestrunner, no shell: each `tests/unit/tst_*.qml` beside the `.js` library it tests: a decision moved out of its QML file, given what it reads, `now` included), `lint` (qmllint over the shell, through the `qs` module Quickshell writes for tools), `calendar-sync` (the script offline, against a calendar served on loopback), `recipes` (each recipe in `docs/src/recipes.md` over the starter, through the shell's check) and `comments` (no comment block over four lines). One case per behaviour a user relies on, run against real commands and files, never stand-ins. What needs a session (PipeWire, UPower, niri, windows) is seen working on the desktop instead. `git add -N` a new test file, or the flake cannot see it.

A fix comes with a test that fails without it: run the suite with the fix reverted, then restored. One suite runs alone with `nix build -L .#checks.x86_64-linux.qml-<concern>`; a check that passed before reruns with `--rebuild`, which also times it. Strip colour codes before grepping a log (`sed 's/\x1b\[[0-9;]*m//g'`): they sit between `WARN` and its category.

`nix run .#quick-key-preview -- <shell dir> [config.json]` runs a working tree in a nested niri, with your `config.json` or a fixture (the built one edited with `jq`), and opens a shell inside it with `wtype`, `wlrctl` and `grim` at hand. It works on a copy of your state, so a plugin's sync writes there, not to yours; its commands still run for real. Exit that shell to stop it. Given a steps file as well, it runs it and exits instead: `ipc menu toggleEntry k`, `key a`, `key -k Escape` and `shot <name>` (a PNG in the working directory), its log's warnings printed at the end. Anything that takes keys is tested this way, with real keys, before a release; open levels with `ipc`, as a dropped key lands on another entry. Session actions run for real, so never press them there. `packages/preview/events.json` is a calendar to point `calendar.file` at, around 12 November 2026.

The docs' images come from the `docs-shots` skill, which runs a second instance with nothing personal in it, and a recipe's from `recipe-shots`. Every other screenshot comes from the preview, never from the live shell: the `preview-check` skill takes them and compares them pixel for pixel with another commit. The preview only draws while its window is visible. A pop-up shows on its own change: nudge the microphone (`wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1%+`, then `1%-`), never the output volume or brightness. Anything opened inside the preview runs its `$SHELL`, so never point that at a script.

Work delegated to agents follows the `agent-round` skill: reviewers report verified findings, implementers work in worktrees, and their commits are merged one at a time.

Releases are tags (`v0.1.0`) with GitHub release notes that list option changes first. While on 0.x, a change that breaks a config bumps the minor version.
