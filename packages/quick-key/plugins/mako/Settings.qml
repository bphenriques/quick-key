import qs
import qs.ui

// Defaults that name mako's own tools, as only a plugin named after its tool may (AGENTS.md, rule 2).
PluginSettings {
  // Whether mako's do-not-disturb mode is on, read as the menu opens: mako signals no change of mode.
  read: "makoctl mode | grep -qx do-not-disturb && echo true || echo false"
  // Turns the do-not-disturb mode on or off.
  activate: "makoctl mode -t do-not-disturb"
  // A struck bell, lit, while the mode is on; a bell otherwise.
  show: ({
    "true": { glyph: Glyphs.notificationsPaused, active: true },
    "false": { glyph: Glyphs.notifications }
  })
}
