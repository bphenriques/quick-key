import qs
import qs.ui

// Defaults that name mako's own tools, as only a plugin named after its tool may (AGENTS.md, rule 2).
PluginSettings {
  // Prints whether mako's do-not-disturb mode is on, then again on every change of mode mako signals.
  watch: "m() { makoctl mode | grep -qx do-not-disturb && echo true || echo false; }; m; dbus-monitor --session \"type='signal',path='/fr/emersion/Mako',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'\" | while read -r line; do case $line in *'\"Modes\"'*) m ;; esac; done"
  // Turns the do-not-disturb mode on or off.
  activate: "makoctl mode -t do-not-disturb"
  // A struck bell, lit, while the mode is on; a bell otherwise.
  show: ({
    "true": { glyph: Glyphs.notificationsPaused, active: true },
    "false": { glyph: Glyphs.notifications }
  })
}
