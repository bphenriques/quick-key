# Introduction

A [Quickshell](https://quickshell.org) menu with live status and a calendar, and a pop-up for volume, brightness, keyboard-layout and keep-awake changes; optional plugins add the rest (a workspace minimap, the screen-recording pill, the wallpaper's name). It runs without a config, and `config.json` changes only what you set (see [Configuration](configuration.md)).

## Runtime

Each external command arrives in its feature's settings (`audio.adjust`, `brightness.adjust`) or a plugin's, so swapping a tool means changing the config, not the shell. Unset, a feature falls back to a standard tool from `PATH` where one exists, else shows an empty status. The compositor is the exception: its backend talks to it directly, niri's through its socket.

