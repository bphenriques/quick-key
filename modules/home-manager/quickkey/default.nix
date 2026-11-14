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

  json = pkgs.formats.json { };
  configFile = json.generate "quickkey-config.json" (withoutNulls cfg.settings);
  themeFiles = lib.mapAttrs (name: colors: json.generate "quickkey-theme-${name}.json" colors) cfg.themes;
  presets = map (lib.removeSuffix ".json") (lib.attrNames (builtins.readDir (self + "/packages/quickkey/themes")));
  themeName = cfg.settings.theme.name;

  color =
    description:
    lib.mkOption {
      type = lib.types.str;
      inherit description;
    };
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

    themes = lib.mkOption {
      type = lib.types.attrsOf (
        lib.types.submodule {
          options = {
            background = color "Background colour";
            foreground = color "Text colour";
            primary = color "Colour of what is on or in use";
            alert = color "Colour of what needs attention";
            warning = color "Colour of what may soon need attention";
          };
        }
      );
      default = { };
      description = "Colour themes, written to $XDG_CONFIG_HOME/quickkey/themes/ and picked by `settings.theme.name`";
    };

    exec.ipc = lib.mkOption {
      type = lib.types.str;
      default = "${lib.getExe config.programs.quickshell.package} -c quickkey ipc call";
      defaultText = lib.literalExpression ''"''${lib.getExe config.programs.quickshell.package} -c quickkey ipc call"'';
      description = "Prefix for the shell's IPC calls; append the target and function, e.g. `menu toggle`";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "programs.quickkey" pkgs lib.platforms.linux)
      {
        assertion = themeName == null || cfg.themes ? ${themeName} || lib.elem themeName presets;
        message = "programs.quickkey.settings.theme.name: '${toString themeName}' is neither in programs.quickkey.themes nor a preset: ${toString presets}";
      }
    ];

    xdg.configFile = {
      "quickkey/config.json".source = configFile;
    }
    // lib.mapAttrs' (name: file: lib.nameValuePair "quickkey/themes/${name}.json" { source = file; }) themeFiles;

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
      ]
      ++ map toString (lib.attrValues themeFiles);
    };
  };
}
