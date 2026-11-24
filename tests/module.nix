# What the module writes and runs, its stylix target, and that the build fails on a setting the shell's check rejects.
{ pkgs, evalHome }:
let
  inherit (pkgs) lib;

  configOf = home: home.xdg.configFile."quick-key/config.json".source;

  cfg = evalHome {
    programs.quick-key = {
      extraPackages = [ pkgs.hello ];
      themes.mine = {
        background = "#000000";
        foreground = "#ffffff";
        primary = "#0000ff";
        alert = "#ff0000";
        warning = "#ffff00";
      };
      settings = {
        theme.name = "mine";
        plugins.vpn = {
          type = "command";
          read = "vpn-status";
        };
        menu.entries = lib.mkMerge [
          (lib.mkOrder 200 [
            {
              key = "v";
              desc = "VPN";
              status = "vpn";
              cmd = "vpn-toggle";
            }
          ])
          (lib.mkOrder 100 [
            {
              key = "t";
              desc = "Tray";
              icon = "x";
              list = "tray";
            }
          ])
        ];
      };
    };
  };

  # A theme and a plugin linked out of the store, as the matugen recipe links its theme: the sandbox cannot read either.
  linked = evalHome (
    { config, ... }:
    {
      xdg.configFile."quick-key/themes/matugen.json".source = config.lib.file.mkOutOfStoreSymlink "/nowhere/matugen.json";
      xdg.configFile."quick-key/plugins/mine".source = config.lib.file.mkOutOfStoreSymlink "/nowhere/mine";
      programs.quick-key.settings = {
        theme.name = "matugen";
        plugins.mine.colour = "blue";
        menu.header.left = [ "mine" ];
      };
    }
  );

  failed = settings: lib.filter (a: !a.assertion) (evalHome { programs.quick-key.settings = settings; }).assertions;

  # Stands in for stylix: the options and colours its target reads.
  stylix =
    settings:
    evalHome (
      { lib, ... }:
      {
        options.stylix = {
          enable = lib.mkEnableOption "stylix";
          autoEnable = lib.mkEnableOption "every target" // {
            default = true;
          };
          fonts.monospace.name = lib.mkOption { default = "Stylix Mono"; };
          fonts.sizes.popups = lib.mkOption { default = 13; };
          opacity.popups = lib.mkOption { default = 0.9; };
        };
        config = lib.recursiveUpdate {
          stylix.enable = true;
          lib.stylix.colors.withHashtag = {
            base00 = "#000000";
            base03 = "#333333";
            base05 = "#555555";
            base08 = "#888888";
            base0A = "#aaaaaa";
            base0D = "#dddddd";
          };
        } settings;
      }
    );
in
assert lib.assertMsg (failed { } == [ ]) "the defaults must pass";
assert lib.assertMsg (
  !(cfg.systemd.user.services ? quickshell)
) "quick-key runs as its own service, leaving the user's Quickshell alone";
assert lib.assertMsg (lib.any (a: lib.hasInfix "is neither in programs.quick-key.themes" a.message) (failed {
  theme.name = "nope";
})) "an unknown theme must be rejected";
assert lib.assertMsg (
  (stylix { }).programs.quick-key.settings.theme == {
    name = "stylix";
    monospaceFont = "Stylix Mono";
    fontSize = 13;
    surfaceOpacity = 0.9;
  }
  && (stylix { }).programs.quick-key.themes.stylix.primary == "#dddddd"
) "stylix themes the shell when it themes every target, its colours a theme a named one wins over";
assert lib.assertMsg (
  !((stylix { stylix.autoEnable = false; }).programs.quick-key.settings ? theme)
) "with autoEnable off, stylix leaves the shell alone";
assert lib.assertMsg (
  (stylix {
    stylix.autoEnable = false;
    stylix.targets.quick-key.enable = true;
    programs.quick-key.settings.theme.primary = "#123456";
  }).programs.quick-key.settings.theme.primary == "#123456"
) "the target turns on by itself, and a colour of the user's own wins over stylix's";
assert lib.assertMsg (cfg.programs.quick-key.settings.theme == { name = "mine"; }) "without stylix, nothing is themed";
assert lib.assertMsg (
  (evalHome {
    programs.quick-key.calendarSync.enable = true;
    programs.quick-key.settings.calendar.file = "/elsewhere/events.json";
  }).programs.quick-key.settings.calendar.file == "/elsewhere/events.json"
) "a calendar file set by hand wins over calendar-sync's";
assert lib.assertMsg (
  (evalHome { programs.quick-key.calendarSync.enable = true; })
  .systemd.user.services.quick-key-calendar-sync.Service.RestartMaxDelaySec == "30min"
) "a sync that keeps failing retries ever less often, not every minute";
assert lib.assertMsg (
  let
    inherit ((evalHome { programs.quick-key.calendarSync.enable = true; }).programs.quick-key.calendarSync) exec;
  in
  lib.all (verb: lib.hasSuffix " --" exec.${verb}) [
    "done"
    "reopen"
    "add"
  ]
) "a task's command ends its flags, so a title like one (-x) is still a title";
pkgs.runCommand "quick-key-module-eval"
  {
    nativeBuildInputs = [ pkgs.jq ];
    rejected = pkgs.testers.testBuildFailure (
      configOf (evalHome {
        programs.quick-key.settings.audio.stepp = 1;
      })
    );
  }
  ''
    config=${configOf cfg}
    launcher=${toString cfg.systemd.user.services.quick-key.Service.ExecStart}
    grep -q -- '--config quick-key' $launcher
    grep -q 'PATH=[^:]*-hello-[^:]*/bin:[^:]*util-linux' $launcher
    jq -e '.plugins.vpn == { type: "command", read: "vpn-status" }' $config
    jq -e '.plugins.mine == { colour: "blue" }' ${configOf linked}
    jq -e '.menu.entries | map(.key) == ["t", "v"]' $config
    jq -e '.primary == "#0000ff" and (has("border") | not)' ${cfg.xdg.configFile."quick-key/themes/mine.json".source}
    grep -q 'audio.stepp is not a setting' $rejected/testBuildFailure.log
    touch $out
  ''
