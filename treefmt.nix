_: {
  projectRootFile = "flake.nix";
  programs = {
    # Formatters
    nixfmt.enable = true; # Official Nix formatter.
    nixfmt.width = 120;

    # Checks
    deadnix.enable = true; # Detect unused Nix code
    deadnix.no-lambda-pattern-names = true; # Skip NixOS module args (e.g., { pkgs, lib, ... })
    deadnix.priority = 1; # Run deadnix before statix
    statix.enable = true; # Nix anti-pattern linter
    statix.priority = 2;

    # Python (the stand-in ACP agent the tests run)
    ruff-format.enable = true;
    ruff-check.enable = true;
  };

  # No nushell formatter: nufmt (pre-1.0) rewrites valid scripts into broken ones; writeNushellApplication nu-checks at build.
}
