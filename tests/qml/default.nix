# The shell's logic in a real Quickshell, headless: shell.qml replaces the shipped one and prints a TAP line per case.
{ pkgs, self }:
pkgs.runCommand "quick-key-qml" { nativeBuildInputs = [ pkgs.quickshell ]; } ''
  export BUILTINS=${pkgs.lib.escapeShellArg (builtins.toJSON (import ../../modules/home-manager/quick-key/builtins.nix))}
  export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run XDG_CONFIG_HOME=${./config} QT_QPA_PLATFORM=offscreen NO_COLOR=1 LC_ALL=C.UTF-8
  mkdir -p $XDG_RUNTIME_DIR $HOME/.local/state/quick-key
  cp ${./events.json} $HOME/.local/state/quick-key/events.json
  cp -r ${self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key}/share/quick-key shell
  chmod -R u+w shell
  cp ${./shell.qml} shell/shell.qml
  timeout 60 qs -p shell 2>&1 | tee log
  grep -q '# done' log
  if grep -q 'not ok' log; then exit 1; fi
  touch $out
''
