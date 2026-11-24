---
name: recipe-shots
description: Run a docs recipe of quick-key (docs/src/recipes.md) in the preview and take its image for docs/src/images. Use when adding a recipe, or when a visible change makes a recipe's image stale.
---

# Recipe shots

A recipe's image proves it runs. Each recipe is a fixture in `recipes/`: `<name>.jq`, its settings over `scripts/base.jq` (the starter menu without audio devices, network, Bluetooth or battery, English dates, the preview's events), and `<name>.sh`, the steps that drive the preview (`ipc`, `key`, `shot <image>`, see `packages/preview/script.sh`). The preview runs on its own session bus, so no tray app or player of the user's shows.

1. Write the recipe in `docs/src/recipes.md`, then its fixture: the same settings as JSON, `<glyph>` filled in with a real Nerd Font glyph, a place pinned rather than guessed from the address.
2. Take it, from the repo's root; the nested niri opens as a window and only draws while it is visible, so keep its workspace on screen:
   ```bash
   bash .agents/skills/recipe-shots/scripts/shot.sh <name>...
   ```
   Each `shot` lands in `docs/src/images/<image>.png`, cropped to what differs from the empty output. Any warning the shell logs (a setting the check rejects) is printed.
3. Look at each image: nothing personal shows, and the recipe's part is there. Reference it from the recipe: `![What it shows](images/<image>.png)`.

The steps run commands for real: never press a session action, change volume or brightness, and undo what a recipe starts (`focus.sh` stops its timer and removes its file). Stop a process by a pattern anchored to its command's start (`pkill -f '^[^ ]*sh -c for m'`, as sh runs by its full path), as a loose one matches the shell that runs the script.
