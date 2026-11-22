import QtQuick
import Quickshell.Io

// A config command run for as long as it lasts, read by line; restarts back off up to a minute, so a missing tool cannot spin.
CommandProcess {
  id: root

  property string shell

  signal read(string line)

  function start() {
    if (!shell || running) return;
    exec(["sh", "-c", shell]);
  }

  Component.onCompleted: start()

  // A new command replaces the running one once it exits.
  onShellChanged: if (running) running = false; else start()

  property int delay: 2000

  onExited: {
    if (!shell) return;
    restart.interval = delay;
    restart.restart();
    delay = Math.min(delay * 2, 60000);
  }

  stdout: SplitParser {
    onRead: line => {
      root.delay = 2000;
      root.read(line);
    }
  }

  property Timer restart: Timer {
    onTriggered: root.start()
  }
}
