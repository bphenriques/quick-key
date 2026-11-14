{ lib, stdenvNoCC }:
stdenvNoCC.mkDerivation {
  name = "quickkey";
  src = lib.fileset.toSource {
    root = ./.;
    fileset = lib.fileset.unions [
      ./shell.qml
      ./Config.qml
      ./Integration.qml
      ./services
      ./ui
      ./widgets
      ./integrations
    ];
  };
  doCheck = true;
  checkPhase = "bash -euo pipefail ${./check.sh}";
  installPhase = ''
    mkdir -p $out/share/quickkey
    cp -r . $out/share/quickkey
  '';
  meta.platforms = lib.platforms.linux;
}
