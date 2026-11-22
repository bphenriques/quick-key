pragma Singleton

import QtQuick
import Quickshell
import qs

// The names on the system bus, running or started on demand (Config.daemons.list), read at start and as the menu opens: a built-in that needs a daemon is offered only where it is (power profiles).
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
    atStart: true
    onRead: text => internal.names = text.split("\n").map(line => line.trim().split(/\s+/)[0]).filter(name => name)
  }
}
