# Docs site (GitHub Pages): the mdBook in docs/, with the generated `programs.quick-key` options reference
# injected over the placeholder at build time.
{ pkgs, self }:
let
  inherit (pkgs) lib;
  repo = "https://github.com/bphenriques/quick-key";

  # Only the options are read, so the module's home-manager config targets can stay undeclared.
  eval = lib.evalModules {
    modules = [
      self.homeManagerModules.default
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
  { echo "# Options reference"; echo; cat ${optionsDoc.optionsCommonMark}; } > book/src/options.md
  mdbook build book -d $out
''
