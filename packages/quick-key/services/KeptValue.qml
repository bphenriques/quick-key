import QtQuick
import Quickshell
// By name, not as the folder: so tools see Kept as the singleton it is.
import qs.services

// A value Kept keeps, to bind to: it wakes only when its own key changes, never for another's; set it through Kept.set.
Scope {
  id: root

  required property string key
  readonly property var value: internal.value

  QtObject {
    id: internal
    property var value: Kept.value(root.key)
  }

  Connections {
    target: Kept

    function onChanged(key) {
      if (key === root.key) internal.value = Kept.value(key);
    }
  }
}
