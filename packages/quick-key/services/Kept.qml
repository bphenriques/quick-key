pragma Singleton

import QtQuick
import Quickshell

// What you chose while the shell runs (keep awake on, a draft, a list's order, a conversation), by key, kept over a reload, which a change to config.json makes: shell.qml carries it over, as only its own tree's PersistentProperties survive one.
Singleton {
  readonly property var values: internal.values

  // Its values are back after a reload, for what takes them imperatively (a conversation).
  signal restored

  function set(key, value) {
    internal.values = Object.assign({}, internal.values, { [key]: value });
  }

  // From shell.qml, with what it carried over.
  function restore(values) {
    internal.values = values;
    restored();
  }

  QtObject {
    id: internal
    property var values: ({})
  }
}
