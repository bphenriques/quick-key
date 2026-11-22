# Introduction

quick-key is a keyboard menu with live status for [Quickshell](https://quickshell.org): one key opens it, and every row shows the state of what it controls. A pop-up shows volume, brightness, keyboard layout and keep-awake changes.

It is a menu first. It sits beside the bar or shell you have and replaces neither. Plugins add the rest, most of them a command and a few lines of config (see [Recipes](recipes.md)).

It runs without a config; `config.json` changes only what you set (see [Configuration](configuration.md)).

## How it reaches the system

- **Built in:** volume, mute, Wi-Fi and Bluetooth power, playback and the tray go through Quickshell's own services. No tool is needed.
- **Through the config:** anything else is a command you set, such as `brightness.set` or a plugin's. Swapping a tool means changing the config, not the shell. Unset, a standard tool from `PATH` is used where one exists.
- **The compositor:** a backend talks to it directly. niri is the only one today.
