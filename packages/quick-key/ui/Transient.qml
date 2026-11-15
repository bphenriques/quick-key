import QtQuick
import qs

// Shown for Config.popups.timeout on show(), held while `held`; inert until `armed`, so state replayed at startup is no change.
Timer {
  id: root

  property bool shown: false
  property bool held: false
  property bool armed: true

  function show() {
    if (!armed) return;
    shown = true;
    restart();
  }

  function hide() {
    stop();
    shown = false;
  }

  interval: Config.popups.timeout
  onTriggered: held ? restart() : hide()
}
