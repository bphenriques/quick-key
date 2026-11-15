```bash
nix fmt                     # format + lint (treefmt)
nix flake check -L          # formatting, package builds (check.sh included) and tests
nix build .#docs            # docs site → result/index.html
```

`packages/quick-key/check.sh` holds the design rules in [AGENTS.md](AGENTS.md) that a text search can (a plugin's folder, root, settings and views, its imports, built-ins only in their tables, no optional calls or `flatMap` (Qt's JavaScript cannot run them), Compositor, Label, glyphs through Icon, colours only through tones and the kit, font measures through Metrics, commands from the config, plugins declaring no source or IPC of their own); every build runs it.

`tests/` holds the flake checks beyond the builds, listed in `tests/default.nix`: `module-eval` (what the module writes into `config.json`, and that the build fails on a setting the check rejects) and `qml-<concern>` (the shell's logic in a real Quickshell, headless, one check per folder of `tests/qml/`: its `shell.qml` holds the cases, a TAP line each, and the rest of the folder is the config they run against) and `comments` (no comment over one line). One case per behaviour a user relies on, run against real commands and files, never stand-ins. What needs a session (PipeWire, UPower, niri, windows) is seen working on the desktop instead. `git add -N` a new test file, or the flake cannot see it.

`nix run .#quick-key-preview -- <shell dir> [config.json]` runs a working tree in a nested niri, with your `config.json` or a fixture (the built one edited with `jq`), and opens a shell inside it with `wtype`, `wlrctl` and `grim` at hand. Exit that shell to stop it. Session actions run for real, so never press them there. `packages/preview/events.json` is a calendar to point `calendar.file` at, around 12 November 2026.

Screenshots come from the live desktop after a switch, not the preview (it only draws while its window is visible): open a level with `qs -c quick-key ipc call menu toggleEntry <key>` (`menu toggle` for the top level), wait a second, `grim <file>`, then close it with `menu toggle`. A pop-up shows on its own change (`niri msg action switch-layout next`, `qs -c quick-key ipc call idle toggle`, then the same again to undo). Anything opened inside the preview runs its `$SHELL`, so never point that at a script.

Releases are tags (`v0.1.0`) with GitHub release notes that list option changes first. While on 0.x, a change that breaks a config bumps the minor version.
