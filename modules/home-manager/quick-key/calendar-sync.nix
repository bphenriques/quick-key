self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quick-key.calendarSync;
in
{
  options.programs.quick-key.calendarSync = {
    enable = lib.mkEnableOption "syncing calendars into the events the month shows";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key-calendar-sync;
      defaultText = lib.literalExpression "quick-key.packages.\${pkgs.stdenv.hostPlatform.system}.quick-key-calendar-sync";
      description = "calendar-sync package";
    };

    calendars = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/quick-key/calendars.yaml";
      defaultText = lib.literalExpression ''"''${config.xdg.configHome}/quick-key/calendars.yaml"'';
      description = "Calendar list, edited by hand since its URLs are secret; starts as the sample, and saving it syncs";
    };

    eventsFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/quick-key/events.json";
      defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/quick-key/events.json"'';
      description = "Events written for the shell, with vdirsyncer's and khal's own files beside it";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/30";
      description = "How often to sync, as a systemd OnCalendar expression";
    };

    exec.sync = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${lib.getExe' pkgs.systemd "systemctl"} --user start --no-block quick-key-calendar-sync.service";
      defaultText = lib.literalExpression ''"''${lib.getExe' pkgs.systemd "systemctl"} --user start --no-block quick-key-calendar-sync.service"'';
      description = "Command that syncs now, for a menu entry";
    };
  };

  config = lib.mkIf (config.programs.quick-key.enable && cfg.enable) {
    programs.quick-key.settings.calendar.file = cfg.eventsFile;

    home.activation.quickKeyCalendars = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      [ -e "${cfg.calendars}" ] || run install -Dm600 ${cfg.package.sample} "${cfg.calendars}"
    '';

    systemd.user = {
      # The shell only sees the file appear in a directory that exists when it starts.
      tmpfiles.rules = [ "d ${dirOf cfg.eventsFile} 0700 - - -" ];
      services.quick-key-calendar-sync = {
        Unit.Description = "Syncs the calendars quick-key shows";
        Service = {
          Type = "oneshot";
          # At login the network may not be up yet: retry, and never hang the next tick on a stalled connection.
          Restart = "on-failure";
          RestartSec = "1min";
          TimeoutStartSec = "5min";
          ExecStart = lib.escapeShellArgs [
            (lib.getExe cfg.package)
            cfg.calendars
            cfg.eventsFile
          ];
        };
      };
      timers.quick-key-calendar-sync = {
        Install.WantedBy = [ "timers.target" ];
        Timer = {
          OnCalendar = cfg.interval;
          Persistent = true;
        };
      };
      paths.quick-key-calendar-sync = {
        Install.WantedBy = [ "paths.target" ];
        Path.PathChanged = cfg.calendars;
      };
    };
  };
}
