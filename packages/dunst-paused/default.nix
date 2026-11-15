{
  lib,
  pkgs,
  dunst ? pkgs.dunst,
}:
(import ../builders.nix { inherit pkgs lib; }).writeNushellApplication {
  name = "quick-key-dunst-paused";
  runtimeInputs = [
    dunst
    pkgs.dbus
  ];
  script = ./script.nu;
  meta.platforms = lib.platforms.linux;
}
