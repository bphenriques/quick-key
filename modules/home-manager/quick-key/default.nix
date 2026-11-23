self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quick-key;

  json = pkgs.formats.json { };
  # The user's own plugins, so the check finds them as the shell will; it reads no theme.
  besides = lib.filterAttrs (name: _: lib.hasPrefix "quick-key/plugins/" name) config.xdg.configFile;
  # The shell checks the settings it is given, so a wrong one fails the build, not the session.
  configFile =
    pkgs.runCommand "quick-key-config.json"
      {
        nativeBuildInputs = [
          config.programs.quickshell.package
          pkgs.jq
        ];
        settings = json.generate "quick-key-settings.json" cfg.settings;
      }
      ''
        export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR QT_QPA_PLATFORM=offscreen LC_ALL=C.UTF-8
        install -D $settings $TMPDIR/quick-key/config.json
        unread=()
        ${lib.concatStrings (
          lib.mapAttrsToList (name: file: ''
            if [ -e ${file.source} ]; then mkdir -p "$(dirname $TMPDIR/${name})" && cp -rL ${file.source} $TMPDIR/${name}
            else echo "${name} links out of the store, where the check cannot read it: its settings go unchecked" >&2; unread+=(${lib.head (lib.splitString "/" (lib.removePrefix "quick-key/plugins/" name))}); fi
          '') besides
        )}
        # One unread checks as a command plugin, so what names it still does.
        if [ ''${#unread[@]} -gt 0 ]; then
          jq --args '.plugins |= ((. // {}) | with_entries(if (.value.type // .key) | IN($ARGS.positional[]) then .value = { type: "command" } else . end))' "''${unread[@]}" < $settings > $TMPDIR/quick-key/config.json
        fi
        timeout 60 qs -p ${cfg.package}/share/quick-key/check.qml
        cp $settings $out
      '';
  themeFiles = lib.mapAttrs (
    name: colors: json.generate "quick-key-theme-${name}.json" (lib.filterAttrs (_: color: color != null) colors)
  ) cfg.themes;
  presets = map (lib.removeSuffix ".json") (lib.attrNames (builtins.readDir (self + "/packages/quick-key/themes")));
  # The notifications plugin, under any name: a notification server, as dunst and mako are.
  notificationsListed = lib.any (name: (cfg.settings.plugins.${name}.type or name) == "notifications") (
    lib.attrNames (cfg.settings.plugins or { })
  );
  themeName = cfg.settings.theme.name or null;

  # extraPackages, then the standard tools the shell's and its plugins' defaults name, before the session's PATH; systemd's come with the system.
  launcher = pkgs.writeShellScript "quick-key" ''
    export PATH=${
      lib.makeBinPath (
        cfg.extraPackages
        ++ [
          pkgs.util-linux
          pkgs.libnotify
          pkgs.wl-clipboard
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
  optionalColor =
    description:
    lib.mkOption {
      type = lib.types.nullOr lib.types.str;
      default = null;
      inherit description;
    };
in
{
  imports = [
    (import ./calendar-sync.nix self)
    ./stylix.nix
  ];

  options.programs.quick-key = {
    enable = lib.mkEnableOption "quick-key, a keyboard-driven Quickshell menu with live status";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key;
      defaultText = lib.literalExpression "quick-key.packages.\${pkgs.stdenv.hostPlatform.system}.quick-key";
      description = "Shell package, its QML under share/quick-key";
    };

    settings = lib.mkOption {
      inherit (json) type;
      default = { };
      example = lib.literalExpression ''{ theme.name = "nord"; clock.format = "%H:%M"; }'';
      description = "Written to `$XDG_CONFIG_HOME/quick-key/config.json`, which the shell checks as the configuration builds";
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
            border = optionalColor "Colour of outlines and dividers; unset, the foreground at `theme.disabledOpacity`";
            bubble = optionalColor "Colour of your messages in a conversation; unset, a faint foreground";
            bubbleText = optionalColor "Colour of your messages' text; unset, the text colour";
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
      description = "Packages first on the shell's PATH, for what commands, plugins and notification rules call by name; one here wins over a standard tool's";
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
        # A file of your own under quick-key/themes/ counts too: a link to one matugen or pywal writes.
        assertion =
          themeName == null
          || cfg.themes ? ${themeName}
          || lib.elem themeName presets
          || config.xdg.configFile ? "quick-key/themes/${themeName}.json";
        message = "programs.quick-key.settings.theme.name: '${toString themeName}' is neither in programs.quick-key.themes, a file under quick-key/themes/, nor a preset: ${toString presets}";
      }
      {
        assertion = !(notificationsListed && (config.services.dunst.enable || config.services.mako.enable));
        message = "programs.quick-key: plugins.notifications is a notification server, as services.dunst and services.mako are; keep one, as only one can hold the bus";
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
        # The restart above follows a change, so the shell does not reload itself as well: a reload over a restart only tears down what goes anyway.
        Environment = [ "QUICK_KEY_WATCH_CONFIG=0" ];
        Restart = "on-failure";
      };
      Install.WantedBy = [ config.wayland.systemd.target ];
    };
  };
}
