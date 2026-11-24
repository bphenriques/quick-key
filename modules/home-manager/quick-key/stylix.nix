# Themes the shell from stylix like one of stylix's own targets, so it works without stylix installed.
{ lib, config, ... }:
let
  inherit (config) stylix;
in
{
  options.stylix.targets.quick-key.enable = lib.mkOption {
    type = lib.types.bool;
    default = (stylix.enable or false) && (stylix.autoEnable or false);
    defaultText = lib.literalExpression "config.stylix.enable && config.stylix.autoEnable";
    description = "Whether stylix themes quick-key: its colours, monospace font, and popups' font size and opacity";
  };

  config = lib.mkIf (config.programs.quick-key.enable && stylix.targets.quick-key.enable) {
    # Its colours as a theme of their own, picked by default: a theme you name wins, and a colour you set wins over both.
    programs.quick-key.themes.stylix = with config.lib.stylix.colors.withHashtag; {
      background = base00;
      foreground = base05;
      primary = base0D;
      alert = base08;
      warning = base0A;
      border = base03;
    };
    programs.quick-key.settings.theme = lib.mapAttrs (_: lib.mkDefault) {
      name = "stylix";
      monospaceFont = stylix.fonts.monospace.name;
      # The shell's size is whole points; stylix's may be a fraction.
      fontSize = builtins.floor (stylix.fonts.sizes.popups + 0.5);
      surfaceOpacity = stylix.opacity.popups;
    };
  };
}
