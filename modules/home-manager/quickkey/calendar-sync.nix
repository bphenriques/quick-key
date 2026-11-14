self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quickkey.calendarSync;
in
{
  options.programs.quickkey.calendarSync = {
    enable = lib.mkEnableOption "syncing calendars into the events the month shows";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quickkey-calendar-sync;
      defaultText = lib.literalExpression "quickkey.packages.\${pkgs.stdenv.hostPlatform.system}.quickkey-calendar-sync";
      description = "calendar-sync package";
    };

    calendars = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.configHome}/quickkey/calendars.yaml";
      defaultText = lib.literalExpression ''"''${config.xdg.configHome}/quickkey/calendars.yaml"'';
      description = "Calendar list, edited by hand since its URLs are secret; starts as the sample, and saving it syncs";
    };

    eventsFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/quickkey/events.json";
      defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/quickkey/events.json"'';
      description = "Events written for the shell, with vdirsyncer's and khal's own files beside it";
    };

    interval = lib.mkOption {
      type = lib.types.str;
      default = "*:0/30";
      description = "How often to sync, as a systemd OnCalendar expression";
    };
  };

  config = lib.mkIf (config.programs.quickkey.enable && cfg.enable) {
    programs.quickkey.settings.calendar.file = cfg.eventsFile;

    home.activation.quickkeyCalendars = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
      [ -e "${cfg.calendars}" ] || run install -Dm600 ${cfg.package.sample} "${cfg.calendars}"
    '';

    systemd.user = {
      # The shell only sees the file appear in a directory that exists when it starts.
      tmpfiles.rules = [ "d ${dirOf cfg.eventsFile} 0700 - - -" ];
      services.quickkey-calendar-sync = {
        Unit.Description = "Syncs the calendars quickkey shows";
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
      timers.quickkey-calendar-sync = {
        Install.WantedBy = [ "timers.target" ];
        Timer = {
          OnCalendar = cfg.interval;
          Persistent = true;
        };
      };
      paths.quickkey-calendar-sync = {
        Install.WantedBy = [ "paths.target" ];
        Path.PathChanged = cfg.calendars;
      };
    };
  };
}
