# qmllint over the shell, through the qs module Quickshell writes for tools once a .qmlls.ini exists; what it cannot type is left out (Config's JSON adapter, Quickshell's own singletons and types), so whatever it does say fails the check.
{ pkgs, self }:
pkgs.runCommand "quick-key-lint"
  {
    nativeBuildInputs = [
      pkgs.quickshell
      pkgs.qt6.qtdeclarative
    ];
  }
  ''
    export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run QT_QPA_PLATFORM=offscreen
    mkdir -p $XDG_RUNTIME_DIR
    cp -r ${self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key}/share/quick-key shell
    chmod -R u+w shell
    touch shell/.qmlls.ini
    timeout 10 qs -p shell > qs.log 2>&1 || true
    vfs=$(sed -n 's/^buildDir="\(.*\)"$/\1/p' shell/.qmlls.ini)
    IFS=: read -ra paths <<< "$(sed -n 's/^importPaths="\(.*\)"$/\1/p' shell/.qmlls.ini)"
    args=()
    for path in "''${paths[@]}"; do args+=(-I "$path"); done
    cd "$vfs/qs"
    qmllint "''${args[@]}" -I "$vfs" --missing-property disable --import disable --unresolved-type disable --uncreatable-type disable --unused-imports warning --max-warnings 0 $(find . -name '*.qml' ! -name Config.qml | sort)
    touch $out
  ''
