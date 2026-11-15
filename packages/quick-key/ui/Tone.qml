pragma Singleton

import QtQuick
import Quickshell
import qs

// Each tone's colour; dim is the normal one at reduced alpha, so widgets never set opacity to dim.
Singleton {
  function color(tone) {
    switch (tone) {
    case "primary": return Config.colors.primary;
    case "warning": return Config.colors.warning;
    case "alert": return Config.colors.alert;
    case "dim": return Qt.alpha(Config.colors.foreground, Config.theme.dimOpacity);
    default: return Config.colors.foreground;
    }
  }

  // The background of a panel, at the theme's opacity unless given.
  function surface(opacity = Config.theme.surfaceOpacity) {
    return Qt.alpha(Config.colors.background, opacity);
  }

  // A tone's colour behind something: a highlight, or a meter's track. `strength` multiplies theme.highlightOpacity.
  function wash(tone, strength = 1) {
    return Qt.alpha(color(tone), strength * Config.theme.highlightOpacity);
  }
}
