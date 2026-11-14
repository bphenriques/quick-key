{
  description = "quickkey: a keyboard-driven Quickshell menu with live status, in the style of which-key";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
    }:
    let
      inherit (nixpkgs) lib;
      systems = [
        "x86_64-linux"
        "aarch64-linux"
      ];
      forAllSystems = lib.genAttrs systems;
      treefmtEval = forAllSystems (system: treefmt-nix.lib.evalModule nixpkgs.legacyPackages.${system} ./treefmt.nix);

      shellPackages = pkgs: rec {
        quickkey = pkgs.callPackage ./packages/quickkey { };
        quickkey-calendar-sync = pkgs.callPackage ./packages/calendar-sync { };
        quickkey-preview = pkgs.callPackage ./packages/preview { };
        default = quickkey;
      };
    in
    {
      packages = forAllSystems (
        system:
        let
          pkgs = nixpkgs.legacyPackages.${system};
        in
        shellPackages pkgs
        // {
          docs = import ./docs.nix { inherit pkgs self; };
        }
      );

      homeManagerModules.default = import ./modules/home-manager/quickkey self;

      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      checks = forAllSystems (
        system:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
        // removeAttrs (shellPackages nixpkgs.legacyPackages.${system}) [ "default" ]
      );

      devShells = forAllSystems (system: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${system}; };
      });
    };
}
