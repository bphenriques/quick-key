# Each nix block of the recipes over the starter, through the shell's check, so a recipe passes as pasted.
{ pkgs, self }:
let
  inherit (pkgs) lib;
  starter = (lib.importJSON "${self}/packages/quick-key/menu.json").menu;
  blocks = lib.filter lib.isList (
    builtins.split "```nix\n(([^`]|`[^`])*)```" (builtins.readFile "${self}/docs/src/recipes.md")
  );
  # A bare entry joins the entries and one naming the starter sets them; a module (Extend the starter) is no recipe.
  recipe =
    text:
    let
      s = import (builtins.toFile "recipe.nix" "starter: { ${if lib.hasPrefix "{" text then "menu.entries = [ ${text} ];" else text} }") starter;
    in
    lib.recursiveUpdate s {
      menu.entries = lib.optionals (!lib.hasInfix "starter" text) starter.entries ++ s.menu.entries or [ ];
      menu.header.right = starter.header.right ++ s.menu.header.right or [ ];
    };
  recipes = map recipe (lib.filter (text: !lib.hasPrefix "{ inputs" text) (map lib.head blocks));
in
pkgs.runCommand "quick-key-recipes" { nativeBuildInputs = [ pkgs.quickshell ]; } ''
  export HOME=$TMPDIR XDG_CONFIG_HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR QT_QPA_PLATFORM=offscreen LC_ALL=C.UTF-8
  ${lib.concatImapStrings (i: settings: ''
    echo "recipe ${toString i}"
    install -Dm644 ${(pkgs.formats.json { }).generate "recipe-${toString i}.json" settings} $TMPDIR/quick-key/config.json
    timeout 60 qs -p ${self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key}/share/quick-key/check.qml
  '') recipes}
  touch $out
''
