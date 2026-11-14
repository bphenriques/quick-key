{ lib, pkgs }:
(import ../builders.nix { inherit pkgs lib; }).writeNushellApplication {
  name = "quickkey-calendar-sync";
  runtimeInputs = [
    pkgs.vdirsyncer
    pkgs.khal
    pkgs.coreutils
  ];
  script = ./script.nu;
  # Where the list starts from: its format, with an example commented out.
  passthru.sample = ./calendars.yaml;
  meta.platforms = lib.platforms.linux;
}
