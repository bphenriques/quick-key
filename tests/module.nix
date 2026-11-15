# What the module writes and runs, and that the build fails on a setting the shell's check rejects.
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
              list = "tray";
            }
          ])
        ];
      };
    };
  };

  failed = settings: lib.filter (a: !a.assertion) (evalHome { programs.quick-key.settings = settings; }).assertions;
in
assert lib.assertMsg (failed { } == [ ]) "the defaults must pass";
assert lib.assertMsg (
  !(cfg.systemd.user.services ? quickshell)
) "quick-key runs as its own service, leaving the user's Quickshell alone";
assert lib.assertMsg (lib.any (a: lib.hasInfix "neither in programs.quick-key.themes nor a preset" a.message) (failed {
  theme.name = "nope";
})) "an unknown theme must be rejected";
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
    jq -e '.menu.entries | map(.key) == ["t", "v"]' $config
    jq -e '.primary == "#0000ff"' ${cfg.xdg.configFile."quick-key/themes/mine.json".source}
    grep -q 'audio.stepp is not a setting' $rejected/testBuildFailure.log
    touch $out
  ''
