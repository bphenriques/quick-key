---
name: record-tour
description: Record the README's video tour of quick-key on the live niri desktop, with made-up events. Use when the tour needs re-recording after a visible change.
---

# Record tour

Drives the deployed shell on the live desktop, so deploy the change first. The script swaps in a copy of the live config with made-up events (`scripts/events.json`, dated from today) and no Wi-Fi entry, records about 20 seconds of the menu from an empty workspace, then restores the config and workspace.

1. Record:
   ```bash
   nix shell nixpkgs#wl-screenrec nixpkgs#ffmpeg-headless nixpkgs#wtype nixpkgs#jq \
     -c bash .agents/skills/record-tour/scripts/record.sh <out.mp4>
   ```
2. Check a few frames (`ffmpeg -ss <seconds> -i <out.mp4> -frames:v 1 <frame.png>`): nothing personal shows, and each level is readable.
3. Hand over the file. The README embeds it through GitHub: dropping it into `README.md` in the web editor uploads it and inserts a `user-attachments` URL. Never commit the video.

The tour presses `a` (audio) and `c` (calendar), so the deployed menu must keep those keys. Keep it under 30 seconds.
