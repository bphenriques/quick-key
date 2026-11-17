{ lib, pkgs }:
(import ../builders.nix { inherit pkgs lib; }).writeNushellApplication {
  name = "quick-key-calendar-sync";
  runtimeInputs = [
    pkgs.vdirsyncer
    pkgs.khal
    pkgs.todoman
    pkgs.util-linux
    pkgs.coreutils
  ];
  script = ./script.nu;
  # todoman loads its config as Python: no __pycache__ beside it.
  runtimeEnv.PYTHONDONTWRITEBYTECODE = "1";
  # Where the list starts from: its format, with an example commented out.
  passthru.sample = ./calendars.yaml;
  meta.platforms = lib.platforms.linux;
}
