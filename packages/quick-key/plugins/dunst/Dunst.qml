import qs

// dunst's do-not-disturb, all of it data in Settings.qml: a bell, red while notifications are paused.
Plugin {
  function activate() {
    exec(settings.activate);
  }
}
