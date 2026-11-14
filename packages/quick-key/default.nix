{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  name = "quick-key";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./shell.qml
      ./Config.qml
      ./ThemeFile.qml
      ./menu.json
      ./Plugin.qml
      ./services
      ./ui
      ./widgets
      ./plugins
      ./themes
    ];
  };
  doCheck = true;
  checkPhase = "bash -euo pipefail ${./check.sh}";
  installPhase = ''
    mkdir -p $out/share/quick-key
    cp -r . $out/share/quick-key
  '';
  meta.platforms = lib.platforms.linux;
}
