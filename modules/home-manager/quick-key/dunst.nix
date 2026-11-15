self:
{
  lib,
  pkgs,
  config,
  ...
}:
let
  cfg = config.programs.quick-key.integrations.dunst;
  dunst = config.services.dunst.package;
in
{
  options.programs.quick-key.integrations.dunst = {
    enable = lib.mkEnableOption "the doNotDisturb plugin for dunst: a bell, red while notifications are paused, a click pausing or resuming them";

    package = lib.mkOption {
      type = lib.types.package;
      default = self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key-dunst-paused.override { inherit dunst; };
      defaultText = lib.literalExpression "quick-key.packages.\${pkgs.stdenv.hostPlatform.system}.quick-key-dunst-paused.override { dunst = config.services.dunst.package; }";
      description = "Package printing whether dunst is paused on every change";
    };
  };

  # Each value a default, so settings.plugins.doNotDisturb can change any of it, and place it with menu.header or an entry.
  config = lib.mkIf cfg.enable {
    programs.quick-key.settings.plugins.doNotDisturb = {
      source = lib.mkDefault "command";
      settings = {
        watch = lib.mkDefault (lib.getExe cfg.package);
        activate = lib.mkDefault "${lib.getExe' dunst "dunstctl"} set-paused toggle";
        show = {
          "true" = {
            glyph = lib.mkDefault "󰂛";
            tone = lib.mkDefault "alert";
            active = lib.mkDefault true;
          };
          "false".glyph = lib.mkDefault "󰂚";
        };
      };
    };
  };
}
