_: {
  projectRootFile = "flake.nix";
  programs = {
    # Formatters
    nixfmt.enable = true;
    nixfmt.width = 120;

    # Checks
    deadnix.enable = true;
    deadnix.no-lambda-pattern-names = true; # Skip NixOS module args (e.g., { pkgs, lib, ... })
    deadnix.priority = 1;
    statix.enable = true;
    statix.priority = 2;

    # Python (the stand-in ACP agent the tests run)
    ruff-format.enable = true;
    ruff-check.enable = true;
  };

  # No nushell formatter: nufmt (pre-1.0) rewrites valid scripts into broken ones; writeNushellApplication nu-checks at build.
}
