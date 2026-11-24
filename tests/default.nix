# Flake checks beyond the builds: what the module writes and rejects, and the shell's logic run headless.
{
  pkgs,
  self,
  home-manager,
}:
let
  # home-manager's evaluation without the check that throws on a failed assertion, so tests can read config.assertions.
  hmLib = import "${home-manager}/modules/lib/stdlib-extended.nix" pkgs.lib;
  evalHome =
    module:
    (hmLib.evalModules {
      class = "homeManager";
      specialArgs.modulesPath = "${home-manager}/modules";
      modules =
        import "${home-manager}/modules/modules.nix" {
          inherit pkgs;
          lib = hmLib;
        }
        ++ [
          self.homeModules.default
          {
            home = {
              username = "test";
              homeDirectory = "/home/test";
              stateVersion = "25.11";
            };
            programs.quick-key.enable = true;
          }
          module
        ];
    }).config;
in
{
  module-eval = import ./module.nix { inherit pkgs evalHome; };
  comments = import ./comments.nix { inherit pkgs self; };
  lint = import ./lint.nix { inherit pkgs self; };
  recipes = import ./recipes.nix { inherit pkgs self; };
  unit = import ./unit.nix { inherit pkgs self; };
  calendar-sync = import ./calendar-sync { inherit pkgs self; };
}
// import ./qml { inherit pkgs self; }
