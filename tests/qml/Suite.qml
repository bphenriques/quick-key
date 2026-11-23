import QtQuick
import Quickshell

// Runs `cases` in order and prints a TAP line for each: `start` once, then up to its `timeout` (five seconds) for `until` to hold, checked at once and every 50 ms after.
Scope {
  id: root

  required property var cases
  // Milliseconds the current case has waited.
  property int waited: 0
  property int index: -1

  function next() {
    index++;
    if (index === cases.length) {
      console.info("# done");
      Qt.quit();
      return;
    }
    waited = 0;
    if (cases[index].start) cases[index].start();
    check();
  }

  function check() {
    const passed = cases[index].until();
    if (!passed && waited < (cases[index].timeout ?? 5000)) {
      poll.start();
      return;
    }
    poll.stop();
    console.info((passed ? "ok " : "not ok ") + (index + 1) + " - " + cases[index].name);
    // Past what the shell left for later (Qt.callLater), so none of it lands in the next case.
    Qt.callLater(next);
  }

  Component.onCompleted: Qt.callLater(next)

  Timer {
    id: poll
    interval: 50
    repeat: true
    onTriggered: {
      root.waited += interval;
      root.check();
    }
  }
}
