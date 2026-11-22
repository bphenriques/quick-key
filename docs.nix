# Docs site: the mdBook in docs/, the reference (the settings Config.qml and each plugin declare, the module's options) generated over its placeholder.
{ pkgs, self }:
let
  inherit (pkgs) lib;
  repo = "https://github.com/bphenriques/quick-key";

  # Only the options are read, so the module's home-manager config targets can stay undeclared.
  eval = lib.evalModules {
    modules = [
      self.homeModules.default
      { _module.check = false; }
    ];
    specialArgs = { inherit pkgs; };
  };

  optionsDoc = pkgs.nixosOptionsDoc {
    options = eval.options.programs.quick-key;
    warningsAreErrors = false;
    transformOptions =
      opt:
      opt
      // {
        declarations = map (
          decl:
          let
            rel = lib.removePrefix "${toString self}/" (toString decl);
          in
          {
            name = rel;
            url = "${repo}/blob/main/${rel}";
          }
        ) opt.declarations;
      };
  };
in
pkgs.runCommand "quick-key-docs" { nativeBuildInputs = [ pkgs.mdbook ]; } ''
  cp -r --no-preserve=mode ${./docs} book
  {
    echo "# Reference"; echo
    echo "## Settings"; echo
    echo 'Every key of `config.json` (`programs.quick-key.settings` with Nix), with its default, as the shell declares them:'; echo
    echo '```qml'; sed -n '/^      id: adapter$/,/^    }$/p' ${./packages/quick-key/Config.qml} | sed '1,2d;$d;s/^      //'; echo '```'; echo
    echo "## Plugin settings"; echo
    echo 'Every plugin takes these, under `plugins.<name>`, then its own, with their defaults:'; echo
    # A Settings.qml's top level: each setting it declares or sets, with its comment; its helpers left out.
    settings() { echo '```qml'; awk '/^  \/\/ /{c=c $0 "\n"; next} /^  (property [a-z]+ [A-Za-z]+|[a-z][A-Za-z]*:)/{printf "%s%s\n", c, $0} {c=""}' "$1" | sed 's/^  //'; echo '```'; echo; }
    settings ${./packages/quick-key/PluginSettings.qml}
    for file in ${./packages/quick-key/plugins}/*/Settings.qml; do
      if grep -qE '^  (property |[a-z][A-Za-z]*:)' "$file"; then echo "### $(basename "$(dirname "$file")")"; echo; settings "$file"; fi
    done
    echo "## Module options"; echo
    cat ${optionsDoc.optionsCommonMark}
  } > book/src/options.md
  mdbook build book -d $out
''
