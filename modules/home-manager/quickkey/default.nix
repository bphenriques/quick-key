self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quickkey;

  # Unset options stay out of config.json, so the shell's own defaults (Config.qml) apply.
  withoutNulls =
    value:
    if lib.isAttrs value then
      lib.mapAttrs (_: withoutNulls) (lib.filterAttrs (_: v: v != null) value)
    else if lib.isList value then
      map withoutNulls value
    else
      value;

  configFile = (pkgs.formats.json { }).generate "quickkey-config.json" (withoutNulls cfg.settings);
in
{
  imports = [
    ./settings.nix
    (import ./calendar-sync.nix self)
  ];

  options.programs.quickkey = {
    enable = lib.mkEnableOption "quickkey, a keyboard-driven Quickshell menu with live status";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quickkey;
      defaultText = lib.literalExpression "quickkey.packages.\${pkgs.stdenv.hostPlatform.system}.quickkey";
      description = "Shell package, its QML under share/quickkey";
    };

    exec.ipc = lib.mkOption {
      type = lib.types.str;
      default = "${lib.getExe config.programs.quickshell.package} -c quickkey ipc call";
      defaultText = lib.literalExpression ''"''${lib.getExe config.programs.quickshell.package} -c quickkey ipc call"'';
      description = "Prefix for the shell's IPC calls; append the target and function, e.g. `menu toggle`";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [ (lib.hm.assertions.assertPlatform "programs.quickkey" pkgs lib.platforms.linux) ];

    xdg.configFile."quickkey/config.json".source = configFile;

    programs.quickshell = {
      enable = true;
      systemd.enable = true;
      activeConfig = "quickkey";
      configs.quickkey = "${cfg.package}/share/quickkey";
    };

    # home-manager swaps the config symlink on switch, which a file watch would not follow; restart instead.
    systemd.user.services.quickshell.Unit = {
      PartOf = [ config.wayland.systemd.target ];
      X-Restart-Triggers = [
        "${cfg.package}"
        "${configFile}"
      ];
    };
  };
}
