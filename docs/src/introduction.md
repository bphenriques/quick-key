# Introduction

A [Quickshell](https://quickshell.org) menu with live status and a calendar, and a pop-up for volume, brightness, keyboard-layout and keep-awake changes; optional integrations add the rest (a workspace minimap, the screen-recording pill, the wallpaper's name). Configured by the home-manager module: `programs.quickkey.settings` is `$XDG_CONFIG_HOME/quickkey/config.json`, the shell's only input, grouped by feature like waybar's modules (`clock`, `audio`, `notifications`, ...). Unset settings are left out, so the shell's defaults apply.

## Runtime

Nothing runs from PATH: each external command arrives in its feature's settings (`audio.devices`, `notifications.toggle`) or an integration's, set by the config that owns the tool, so swapping a tool means changing that config, not the shell. One left unset shows as an empty status. The compositor is the exception: its backend talks to it directly, niri's through its socket.

