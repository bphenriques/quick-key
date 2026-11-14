```bash
nix fmt                     # format + lint (treefmt)
nix flake check -L          # formatting and package builds, check.sh included
nix build .#docs            # docs site → result/index.html
```

`packages/quickkey/check.sh` holds the design rules in [AGENTS.md](AGENTS.md) that a text search can (a plugin's root and imports, Compositor, Label, glyphs through Icon, colours only through tones and the kit, font measures through Metrics, commands from the config, plugin state only through `CommandState`); every build runs it.

`nix run .#quickkey-preview -- <shell dir> [config.json]` runs a working tree in a nested niri, with your `config.json` or a fixture (the built one edited with `jq`), and opens a shell inside it with `wtype`, `wlrctl` and `grim` at hand. Exit that shell to stop it. Session actions run for real, so never press them there. `packages/preview/events.json` is a calendar to point `calendar.file` at, around 12 November 2026.

Screenshots come from the live desktop after a switch, not the preview (it only draws while its window is visible): open a level with `qs -c quickkey ipc call menu toggleEntry <key>` (`menu toggle` for the top level), wait a second, `grim <file>`, then close it with `menu toggle`. A pop-up shows on its own change (`niri msg action switch-layout next`, `qs -c quickkey ipc call idle toggle`, then the same again to undo). Anything opened inside the preview runs its `$SHELL`, so never point that at a script.
