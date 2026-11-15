# Whether dunst's notifications are paused, then again on every change it signals: quick-key's doNotDisturb source.
def main [] {
  print (^dunstctl is-paused | str trim)
  ^dbus-monitor --session "type='signal',path='/org/freedesktop/Notifications',interface='org.freedesktop.DBus.Properties',member='PropertiesChanged'"
  | lines
  | where ($it | str starts-with "signal")
  | each {|_| print (^dunstctl is-paused | str trim) }
  | ignore
}
