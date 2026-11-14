{
  description = "quick-key: a keyboard-driven Quickshell menu with live status, in the style of which-key";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-unstable";
    treefmt-nix.url = "github:numtide/treefmt-nix";
    treefmt-nix.inputs.nixpkgs.follows = "nixpkgs";
    home-manager.url = "github:nix-community/home-manager";
    home-manager.inputs.nixpkgs.follows = "nixpkgs";
  };

  outputs =
    {
      self,
      nixpkgs,
      treefmt-nix,
      home-manager,
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
        quick-key = pkgs.callPackage ./packages/quick-key { };
        quick-key-calendar-sync = pkgs.callPackage ./packages/calendar-sync { };
        quick-key-preview = pkgs.callPackage ./packages/preview { };
        default = quick-key;
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

      homeManagerModules.default = import ./modules/home-manager/quick-key self;

      formatter = forAllSystems (system: treefmtEval.${system}.config.build.wrapper);

      checks = forAllSystems (
        system:
        {
          formatting = treefmtEval.${system}.config.build.check self;
        }
        // removeAttrs (shellPackages nixpkgs.legacyPackages.${system}) [ "default" ]
        // import ./tests {
          pkgs = nixpkgs.legacyPackages.${system};
          inherit self home-manager;
        }
      );

      devShells = forAllSystems (system: {
        default = import ./shell.nix { pkgs = nixpkgs.legacyPackages.${system}; };
      });
    };
}
