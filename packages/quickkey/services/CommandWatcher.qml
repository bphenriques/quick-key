import QtQuick
import Quickshell.Io

// A command from the config that runs for as long as it lasts, read line by line; restarted after it exits, waiting twice as
// long each time it exits without output (up to a minute), so a missing tool cannot spawn forever.
Process {
  id: root

  property string shell

  signal read(string line)

  // The command is set here rather than by a binding: a running binding can turn true before a command binding has it.
  function start() {
    if (!shell || running) return;
    command = ["sh", "-c", shell];
    running = true;
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
