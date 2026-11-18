import qs
import qs.ui

// Defaults that name dunst's own tools, as only a plugin named after its tool may (AGENTS.md, rule 2).
PluginSettings {
  // Whether notifications are paused, then again on every change dunst signals.
  watch: "dunstctl is-paused; dbus-monitor --session \"type='signal',path='/org/freedesktop/Notifications',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'\" | while read -r line; do case $line in signal*) dunstctl is-paused ;; esac; done"
  // Pauses or resumes notifications.
  property string activate: "dunstctl set-paused toggle"
  show: ({
    "true": { glyph: Glyphs.notificationsPaused, active: true },
    "false": { glyph: Glyphs.notifications }
  })
}
