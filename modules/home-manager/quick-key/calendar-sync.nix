self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quick-key.calendarSync;
  taskCommand =
    verb: given: description:
    lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = lib.escapeShellArgs [
        (lib.getExe cfg.package)
        verb
        cfg.calendars
        cfg.eventsFile
        # What the shell appends ("$1" "$2") is never a flag: a task titled -x.
        "--"
      ];
      defaultText = lib.literalMD "calendar-sync's `${verb}`, given ${given}";
      inherit description;
    };
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
      description = "Path of the calendar list (YAML), edited by hand since its URLs are secret; it starts as a commented sample, and saving it syncs";
    };

    eventsFile = lib.mkOption {
      type = lib.types.str;
      default = "${config.xdg.stateHome}/quick-key/events.json";
      defaultText = lib.literalExpression ''"''${config.xdg.stateHome}/quick-key/events.json"'';
      description = "Events written for the shell, in a folder of calendar-sync's own (made 0700, its contents replaced) with vdirsyncer's and khal's files";
    };

    tasksFile = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${dirOf cfg.eventsFile}/tasks.json";
      defaultText = lib.literalExpression ''"''${dirOf config.programs.quick-key.calendarSync.eventsFile}/tasks.json"'';
      description = "Tasks written for the tasks plugin, from the calendars with `tasks: true`";
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

    exec.syncAndWait = lib.mkOption {
      type = lib.types.str;
      readOnly = true;
      default = "${lib.getExe' pkgs.systemd "systemctl"} --user start quick-key-calendar-sync.service";
      defaultText = lib.literalExpression ''"''${lib.getExe' pkgs.systemd "systemctl"} --user start quick-key-calendar-sync.service"'';
      description = "Command that syncs and returns once done, for a script that reads the files after";
    };

    exec.done =
      taskCommand "done" "a task's id and title"
        "Command that ticks a task off, given its id and title, for the tasks plugin";
    exec.reopen =
      taskCommand "reopen" "a task's id and title"
        "Command that unticks a task, given its id and title, for the tasks plugin";
    exec.add =
      taskCommand "add" "a task's title"
        "Command that adds a task to the first list, given its title, for the tasks plugin";
  };

  config = lib.mkIf (config.programs.quick-key.enable && cfg.enable) {
    programs.quick-key.settings.calendar.file = lib.mkDefault cfg.eventsFile;

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
          # A calendar that stays broken retries ever less often, up to the half hour the timer syncs at.
          RestartSteps = 4;
          RestartMaxDelaySec = "30min";
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
