{ pkgs }:
pkgs.mkShellNoCC {
  name = "quickkey";
  meta.description = "Development shell for quickkey";

  packages = [
    pkgs.git
    pkgs.mdbook # `mdbook serve docs`
    pkgs.quickshell
    pkgs.nushell # calendar-sync is a .nu script
  ];
}
