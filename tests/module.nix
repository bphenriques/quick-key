# What the module writes and rejects; unset settings stay out of config.json, where an empty map would replace a default.
{ pkgs, evalHome }:
let
  inherit (pkgs) lib;

  cfg = evalHome {
    programs.quick-key = {
      themes.mine = {
        background = "#000000";
        foreground = "#ffffff";
        primary = "#0000ff";
        alert = "#ff0000";
        warning = "#ffff00";
      };
      settings = {
        theme.name = "mine";
        audio.glyphs.headset = "H";
        plugins.vpn = {
          source = "command";
          settings = {
            read = "vpn-status";
            show.up.glyph = "V";
            items = [ { id = "home"; } ];
          };
        };
        menu.entries = [
          {
            key = "v";
            desc = "VPN";
            status = "vpn";
            cmd = "vpn-toggle";
          }
        ];
      };
    };
  };

  failed = settings: lib.filter (a: !a.assertion) (evalHome { programs.quick-key.settings = settings; }).assertions;
  # By the assertion meant: its message names the reason.
  rejects =
    what: reason: settings:
    lib.assertMsg (lib.any (a: lib.hasInfix reason a.message) (failed settings)) "${what} must be rejected for: ${reason}";
in
assert lib.assertMsg (failed { } == [ ]) "the defaults must pass";
assert lib.assertMsg (
  lib.hasSuffix "--config quick-key" (toString cfg.systemd.user.services.quick-key.Service.ExecStart)
  && !(cfg.systemd.user.services ? quickshell)
) "quick-key runs as its own service, leaving the user's Quickshell alone";
assert rejects "an unknown theme" "neither in programs.quick-key.themes nor a preset" { theme.name = "nope"; };
assert rejects "a plugin with two sources" "set more than one of watch, read and file" {
  plugins.x.settings = {
    watch = "a";
    read = "b";
  };
};
assert rejects "every without read" "set every without read" { plugins.x.settings.every = 5; };
assert rejects "a plugin with a built-in name" "are built-in names" { plugins.sink = { }; };
assert rejects "a list neither built in nor a plugin's" "lists 'nope'" {
  menu.entries = [
    {
      key = "x";
      desc = "X";
      list = "nope";
    }
  ];
};
assert rejects "a pair action with one key" "per key of a pair, so needs two keys" {
  menu.entries = [
    {
      key = "v";
      desc = "Volume";
      action = "sink-volume";
    }
  ];
};
assert rejects "both cmd and action" "needs one of cmd, action" {
  menu.entries = [
    {
      key = "m";
      desc = "Mute";
      cmd = "true";
      action = "sink-mute";
    }
  ];
};
assert rejects "a reserved key" "reserved for the menu" {
  menu.entries = [
    {
      key = "Escape";
      desc = "X";
      cmd = "true";
    }
  ];
};
pkgs.runCommand "quick-key-module-eval" { nativeBuildInputs = [ pkgs.jq ]; } ''
  config=${cfg.xdg.configFile."quick-key/config.json".source}
  jq -e '.audio == { glyphs: { headset: "H" } }' $config
  jq -e '.battery.glyphs == null and .menu.entries[0].icon == null' $config
  jq -e '.plugins.vpn == { source: "command", settings: { read: "vpn-status", show: { up: { glyph: "V" } }, items: [ { id: "home" } ] } }' $config
  jq -e '.menu.entries[0] | has("pins") or has("requires") | not' $config
  jq -e '.primary == "#0000ff"' ${cfg.xdg.configFile."quick-key/themes/mine.json".source}
  touch $out
''
