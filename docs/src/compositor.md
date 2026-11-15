# Compositor

The core asks the compositor for two things, through `Compositor`, and nothing more:

- The outputs connected and the outputs on, each by connector name and by make, model and serial (what `brightness.panel` names).
- The keyboard layouts, the current one, and switching to the next.

A backend per compositor answers them, under `services/compositor/`, picked at startup from the environment (`NIRI_SOCKET` today; another compositor would add its own, such as `HYPRLAND_INSTANCE_SIGNATURE`). Without one, the outputs come from Wayland, which only knows those on, and the keyboard layout status stays empty. A backend ships once it is seen working ([design rule 10](https://github.com/bphenriques/quick-key/blob/main/AGENTS.md#design-rules)): niri today.

What only one compositor has stays with its backend (`Niri`: workspaces, windows, every event), for plugins built on it; such a plugin names its compositor (the workspace map is niri's). What the compositor is told (keys, layer rules, outputs) lives in the Nix modules, never in the shell.

