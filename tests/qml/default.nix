# The shell's logic in a real Quickshell, headless, one check per folder: its shell.qml replaces the shipped one and runs its cases through Suite.qml.
{ pkgs, self }:
let
  inherit (pkgs) lib;

  # Only the options are read, so the module's home-manager config targets can stay undeclared.
  options =
    (lib.evalModules {
      modules = [
        self.homeModules.default
        { _module.check = false; }
      ];
      specialArgs = { inherit pkgs; };
    }).options.programs.quick-key.settings;

  # The settings as Config.qml nests them: a group holds its keys, anything else is one key.
  keysOf = lib.mapAttrs (
    _: option:
    if !lib.isOption option then
      keysOf option
    else if option.type.name == "submodule" then
      keysOf (removeAttrs (option.type.getSubOptions [ ]) [ "_module" ])
    else
      null
  );

  # The folder is the shell's config and state at once, so its config.json, plugins, scripts and events.json are found by name.
  run =
    name: env:
    pkgs.runCommand "quick-key-qml-${name}" ({ nativeBuildInputs = [ pkgs.quickshell ]; } // env) ''
      export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run XDG_CONFIG_HOME=$TMPDIR/home XDG_STATE_HOME=$TMPDIR/home
      export QT_QPA_PLATFORM=offscreen NO_COLOR=1 LC_ALL=C.UTF-8
      mkdir -p $XDG_RUNTIME_DIR $TMPDIR/home
      cp -r ${./. + "/${name}"} $TMPDIR/home/quick-key
      cp -r ${self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key}/share/quick-key shell
      chmod -R u+w shell
      cp ${./Suite.qml} shell/Suite.qml
      cp ${./. + "/${name}/shell.qml"} shell/shell.qml
      timeout 60 qs -p shell 2>&1 | tee log
      grep -q '# done' log
      if grep -q 'not ok' log; then exit 1; fi
      touch $out
    '';
in
{
  qml-plugins = run "plugins" { };
  qml-menu = run "menu" { };
  qml-calendar = run "calendar" { };
  qml-ask = run "ask" { };
  qml-module = run "module" {
    BUILTINS = builtins.toJSON (import ../../modules/home-manager/quick-key/builtins.nix);
    SETTINGS = builtins.toJSON (keysOf options);
  };
}
