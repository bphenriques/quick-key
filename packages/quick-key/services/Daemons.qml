pragma Singleton

import QtQuick
import Quickshell
import qs

// Names on the system bus, running or activatable, read at start and as the menu opens: a built-in needing a daemon (power profiles) is offered only where it is.
Singleton {
  function has(name) {
    return internal.names.includes(name);
  }

  function refresh() {
    reader.refresh();
  }

  QtObject {
    id: internal
    property var names: []
  }

  CommandReader {
    id: reader
    shell: Config.daemons.list
    onRead: text => internal.names = text.split("\n").map(line => line.trim().split(/\s+/)[0]).filter(name => name)
  }
}
