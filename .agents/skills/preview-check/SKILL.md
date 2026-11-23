---
name: preview-check
description: See a quick-key change working in the nested-niri preview with a fixture config and a steps file, and compare its screenshots pixel for pixel against another commit. Use for anything visible, and to prove a refactor keeps the look.
---

# Preview check

Rule 10: a change is done when it is seen working. The preview runs a tree in a nested niri on its own session bus, so nothing of the user's session shows or changes.

1. Write a fixture config (`packages/quick-key/menu.json` edited with `jq`, made-up data only) and a steps file. Steps are shell, sourced by `packages/preview/script.sh` once the shell is up: `ipc <target> <function>` (to the preview's own shell), `key <wtype args>`, `shot <name> [delay]`, `sleep`, plus `$work` (the preview's state folder) and `$shell_pid`. The script runs with `set -u`: read optional variables as `${NAME:-}`.
2. See it once:
   ```bash
   cd "$(mktemp -d)" && WAYLAND_DISPLAY=wayland-1 dbus-run-session -- \
     "$(nix build --no-link --print-out-paths .#quick-key-preview)/bin/quick-key-preview" \
     <repo>/packages/quick-key <config.json> <steps.sh>
   ```
   Shots land in the current folder. Look at every one.
3. Compare with another commit (the look must not change, or the change must be named):
   ```bash
   bash .agents/skills/preview-check/scripts/compare.sh <base ref> <config.json> <steps.sh> [out dir]
   ```
   It prints, per shot, how many pixels differ (`compare -metric AE -fuzz 2%`) and exits 1 on any difference. A clock in the bar changes with the minute: pin it in the fixture, or rerun the base to check the noise.

Rules:
- Never run `qs ipc` or `quickshell ipc` against the live shell; the preview's `ipc` reaches only its own.
- Never change output volume or brightness. To trigger the pop-up, nudge only the microphone (`wpctl set-volume @DEFAULT_AUDIO_SOURCE@ 1%+`, then `1%-`) and check it is back at its value.
- A file a plugin reads (`file` sources) lives under the real `$XDG_RUNTIME_DIR`: use a name of your own, never one the live shell reads, and remove it after.
- Strip colour codes before grepping a log (`sed 's/\x1b\[[0-9;]*m//g'`): they sit between `WARN` and its category.
- The nested niri only draws while its window is visible: keep its workspace on screen.
