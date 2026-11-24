import QtQuick
import Quickshell.Io

// A command from the config, run once it is known and on refresh(), and read whole. A request while it runs runs it once more afterwards, so the last state wins.
CommandProcess {
  id: root

  property string shell
  property bool pending: false

  signal read(string text)

  function refresh() {
    if (!shell) return;
    if (running) pending = true;
    else exec(["sh", "-c", shell]);
  }

  // Both fire as it starts; callLater runs the read once.
  Component.onCompleted: Qt.callLater(refresh)
  onShellChanged: Qt.callLater(refresh)

  onExited: if (pending) {
    pending = false;
    exec(["sh", "-c", shell]);
  }

  stdout: StdioCollector {
    onStreamFinished: root.read(text)
  }
}
