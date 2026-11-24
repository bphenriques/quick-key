# The shell's logic in a real Quickshell, headless, one check per folder: its shell.qml replaces the shipped one and runs its cases through Suite.qml; a TypeError fails it too, as does a view not created for any reason but its window, which needs a session.
{ pkgs, self }:
let
  # This suite runs on a session bus of its own: music played by mpv over MPRIS.
  bus = name: name == "music";
  # The folder is the shell's config and state at once, so its config.json, plugins, scripts and events.json are found by name.
  run =
    name:
    pkgs.runCommand "quick-key-qml-${name}"
      {
        nativeBuildInputs = [
          pkgs.quickshell
          # The stand-in ACP agent (agent.py), in every suite's config.
          (pkgs.python3.withPackages (ps: [ ps.agent-client-protocol ]))
        ]
        ++ pkgs.lib.optionals (bus name) [
          pkgs.dbus
          (pkgs.mpv.override { scripts = [ pkgs.mpvScripts.mpris ]; })
        ];
      }
      ''
        export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run XDG_CONFIG_HOME=$TMPDIR/home XDG_STATE_HOME=$TMPDIR/home
        export QT_QPA_PLATFORM=offscreen NO_COLOR=1 LC_ALL=C.UTF-8
        mkdir -p $XDG_RUNTIME_DIR $TMPDIR/home
        cp -r ${./. + "/${name}"} $TMPDIR/home/quick-key
        chmod u+w $TMPDIR/home/quick-key
        cp ${./agent.py} $TMPDIR/home/quick-key/agent.py
        cp -r ${self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key}/share/quick-key shell
        chmod -R u+w shell
        cp ${./Suite.qml} shell/Suite.qml
        cp ${./. + "/${name}/shell.qml"} shell/shell.qml
        ${pkgs.lib.optionalString (bus name) "dbus-run-session --config-file=${pkgs.dbus}/share/dbus-1/session.conf -- "}timeout 60 qs -p shell 2>&1 | tee log
        grep -q '# done' log
        if grep -qE 'not ok|TypeError' log || grep 'not created' log | grep -vq 'unavailable$'; then exit 1; fi
        touch $out
      '';
in
pkgs.lib.genAttrs' [
  "plugins"
  "menu"
  "calendar"
  "ask"
  "markup"
  "check"
  "load"
  "music"
] (name: pkgs.lib.nameValuePair "qml-${name}" (run name))
