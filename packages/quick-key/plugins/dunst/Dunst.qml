import qs

// dunst's do-not-disturb, all of it data in Settings.qml: a bell, struck and lit while notifications are paused.
Plugin {
  function activate() {
    exec(settings.activate);
  }
}
