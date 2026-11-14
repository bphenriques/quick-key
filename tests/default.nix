# Flake checks beyond the builds: what the module writes and rejects, and the shell's logic run headless.
{
  pkgs,
  self,
  home-manager,
}:
let
  # home-manager's own evaluation (modules/default.nix) without the check that throws on a failed assertion, so a
  # test can read config.assertions.
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
          self.homeManagerModules.default
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
  qml = import ./qml { inherit pkgs self; };
}
