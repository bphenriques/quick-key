# The shell's pure logic in qmltestrunner, without a shell: each tests/unit/tst_*.qml beside the JS library it tests, every one of the shell's in one folder, so their names are unique.
{ pkgs, self }:
pkgs.runCommand "quick-key-unit" { nativeBuildInputs = [ pkgs.qt6.qtdeclarative ]; } ''
  export HOME=$TMPDIR QT_QPA_PLATFORM=offscreen LC_ALL=C.UTF-8
  export QML_IMPORT_PATH=${pkgs.qt6.qtdeclarative}/${pkgs.qt6.qtbase.qtQmlPrefix} QT_PLUGIN_PATH=${pkgs.qt6.qtbase}/${pkgs.qt6.qtbase.qtPluginPrefix}
  mkdir tests
  find ${self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key}/share/quick-key -name '*.js' -exec cp {} tests \;
  cp ${./unit}/tst_*.qml tests
  qmltestrunner -input tests
  touch $out
''
