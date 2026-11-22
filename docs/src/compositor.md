# Compositor

The core asks the compositor for three things, through `Compositor`, and nothing more:

- The outputs connected and the outputs on, each by connector name and by make, model and serial (what `brightness.panel` names).
- The keyboard layouts, the current one, and switching to the next.
- The focused output, by connector name, which the notifications' cards follow.

A backend per compositor answers them, under `services/compositor/`, picked at startup from the environment (`NIRI_SOCKET` today; another compositor would add its own, such as `HYPRLAND_INSTANCE_SIGNATURE`). Without one, the `Wayland` backend answers: the outputs Wayland knows, only those on, and no keyboard layouts. A backend ships once it is seen working ([design rule 10](https://github.com/bphenriques/quick-key/blob/main/AGENTS.md#design-rules)): niri today.

What only one compositor has stays with its backend (`Niri`: workspaces, windows, every event), for plugins built on it; such a plugin names its compositor (the workspace map is niri's). What the compositor is told (keys, layer rules, outputs) lives in the Nix modules, never in the shell.


Each surface is a layer of its own namespace, for the compositor's layer rules (blur, a block on screen capture): `quick-key-menu`, a plugin's panel as `quick-key-<name>`, `quick-key-osd`, `quick-key-notifications`, `quick-key-recording-indicator` and `quick-key-dictation-indicator`, `quick-key-minimap`, `quick-key-keep-awake`, and `quick-key-dismiss`, the click-away area under an open surface. The menu and a panel cover the screen and draw only their cards, so a rule over the whole surface (a shadow, blur without `ignorealpha`) acts on the screen.
