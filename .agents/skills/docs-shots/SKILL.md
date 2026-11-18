---
name: docs-shots
description: Retake the docs' and README's images of quick-key (docs/src/images) on the live niri desktop, with made-up events and a canned assistant. Use when a visible change makes them stale.
---

# Docs shots

The images are public, so nothing personal may show: no real event, name, network or conversation. Drives the deployed shell, so deploy the change first. The script swaps in a copy of the live config with made-up events (the tour's `events.json`, dated from today), no Wi-Fi entry and a canned assistant, takes each image from an empty workspace, then restores the config and workspace.

1. Take them:
   ```bash
   nix shell nixpkgs#grim nixpkgs#wtype nixpkgs#jq nixpkgs#imagemagick \
     -c bash .agents/skills/docs-shots/scripts/shots.sh docs/src/images
   ```
2. Look at each image: nothing personal shows, and each panel is whole.

It presses `a` (audio) and `c` (calendar) through IPC and types a prompt into Ask, so the deployed menu must keep those keys and an `ask` plugin.
