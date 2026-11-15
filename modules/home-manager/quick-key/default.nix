self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quick-key;

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
  configFile = json.generate "quick-key-config.json" (withoutNulls cfg.settings);
  themeFiles = lib.mapAttrs (name: colors: json.generate "quick-key-theme-${name}.json" colors) cfg.themes;
  presets = map (lib.removeSuffix ".json") (lib.attrNames (builtins.readDir (self + "/packages/quick-key/themes")));
  themeName = cfg.settings.theme.name;

  # extraPackages, then the standard tools Config.qml's defaults name, before the session's PATH; systemd's come with the system.
  launcher = pkgs.writeShellScript "quick-key" ''
    export PATH=${
      lib.makeBinPath (
        cfg.extraPackages
        ++ [
          pkgs.util-linux
          pkgs.brightnessctl
          pkgs.libnotify
        ]
      )
    }''${PATH:+:$PATH}
    exec ${lib.getExe config.programs.quickshell.package} --config quick-key
  '';

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

  options.programs.quick-key = {
    enable = lib.mkEnableOption "quick-key, a keyboard-driven Quickshell menu with live status";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key;
      defaultText = lib.literalExpression "quick-key.packages.\${pkgs.stdenv.hostPlatform.system}.quick-key";
      description = "Shell package, its QML under share/quick-key";
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
      description = "Colour themes, written to $XDG_CONFIG_HOME/quick-key/themes/ and picked by `settings.theme.name`";
    };

    extraPackages = lib.mkOption {
      type = lib.types.listOf lib.types.package;
      default = [ ];
      example = lib.literalExpression "[ config.services.dunst.package ]";
      description = "Packages first on the shell's PATH, for what plugins and commands call by name; one here wins over a standard tool's";
    };

    exec.ipc = lib.mkOption {
      type = lib.types.str;
      default = "${lib.getExe config.programs.quickshell.package} -c quick-key ipc call";
      defaultText = lib.literalExpression ''"''${lib.getExe config.programs.quickshell.package} -c quick-key ipc call"'';
      description = "Prefix for the shell's IPC calls; append the target and function, e.g. `menu toggle`";
    };
  };

  config = lib.mkIf cfg.enable {
    assertions = [
      (lib.hm.assertions.assertPlatform "programs.quick-key" pkgs lib.platforms.linux)
      {
        assertion = config.programs.quickshell.package != null;
        message = "programs.quick-key: programs.quickshell.package runs the service, so it cannot be null";
      }
      {
        assertion = themeName == null || cfg.themes ? ${themeName} || lib.elem themeName presets;
        message = "programs.quick-key.settings.theme.name: '${toString themeName}' is neither in programs.quick-key.themes nor a preset: ${toString presets}";
      }
    ];

    xdg.configFile = {
      "quick-key/config.json".source = configFile;
    }
    // lib.mapAttrs' (name: file: lib.nameValuePair "quick-key/themes/${name}.json" { source = file; }) themeFiles;

    # Only adds a config, so a Quickshell of the user's own (a bar) keeps its service.
    programs.quickshell = {
      enable = true;
      configs.quick-key = "${cfg.package}/share/quick-key";
    };

    systemd.user.services.quick-key = {
      Unit = {
        Description = "quick-key, a keyboard-driven Quickshell menu";
        PartOf = [ config.wayland.systemd.target ];
        After = [ config.wayland.systemd.target ];
        # home-manager swaps the config symlink on switch, which a file watch would not follow; restart instead.
        X-Restart-Triggers = [
          "${cfg.package}"
          "${configFile}"
        ]
        ++ map toString (lib.attrValues themeFiles);
      };
      Service = {
        ExecStart = "${launcher}";
        Restart = "on-failure";
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
