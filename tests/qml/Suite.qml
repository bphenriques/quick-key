import QtQuick
import Quickshell

// Runs `cases` in order and prints a TAP line for each: `start` once, then up to its `timeout` (five seconds) for `until` to hold.
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
    poll.start();
  }

  Component.onCompleted: next()

  Timer {
    id: poll
    interval: 50
    repeat: true
    onTriggered: {
      const passed = root.cases[root.index].until();
      root.waited += interval;
      if (!passed && root.waited < (root.cases[root.index].timeout ?? 5000)) return;
      stop();
      console.info((passed ? "ok " : "not ok ") + (root.index + 1) + " - " + root.cases[root.index].name);
      root.next();
    }
  }
}
