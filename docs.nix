# Docs site: the mdBook in docs/, the reference (the settings and names the shell declares, then the module's options) generated over its placeholder.
{ pkgs, self }:
let
  inherit (pkgs) lib;
  repo = "https://github.com/bphenriques/quick-key";
  shell = self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key;

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
pkgs.runCommand "quick-key-docs"
  {
    nativeBuildInputs = [
      pkgs.mdbook
      pkgs.quickshell
    ];
  }
  ''
    cp -r --no-preserve=mode ${./docs} book
    # The shell, run headless, writes what it declares; the XDG folders stay unexpanded, so a default under them reads as written.
    export HOME=$TMPDIR XDG_RUNTIME_DIR=$TMPDIR/run XDG_CONFIG_HOME='$XDG_CONFIG_HOME' XDG_STATE_HOME='$XDG_STATE_HOME' QT_QPA_PLATFORM=offscreen LC_ALL=C.UTF-8
    mkdir -p $XDG_RUNTIME_DIR
    cp -r --no-preserve=mode ${shell}/share/quick-key shell
    cp ${./docs/reference.qml} shell/reference.qml
    OUT=$PWD/book/src/options.md SOURCE=${repo}/blob/main/packages/quick-key/ timeout 60 qs -p shell/reference.qml
    {
      echo "## Module options"; echo
      cat ${optionsDoc.optionsCommonMark}
    } >> book/src/options.md
    mdbook build book -d $out
  ''
