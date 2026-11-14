{ pkgs }:
pkgs.mkShellNoCC {
  name = "quick-key";
  meta.description = "Development shell for quick-key";

  packages = [
    pkgs.git
    pkgs.mdbook # `mdbook serve docs`
    pkgs.quickshell
    pkgs.nushell # calendar-sync is a .nu script
  ];
}
