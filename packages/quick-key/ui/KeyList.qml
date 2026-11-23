pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Keys and what each does, a row each, in one column unless `columns` says more; a click is `picked`.
GridLayout {
  id: root

  // [{ key, desc }], a key being a name or a pair of names.
  property var keys: []
  readonly property int chars: Math.max(1, ...keys.map(hint => MenuKeys.label(hint.key, true).length))

  signal picked(var key)

  columns: 1
  columnSpacing: Metrics.columnGap
  rowSpacing: 0

  Repeater {
    model: root.keys.length

    ListItem {
      id: entry
      required property int index
      readonly property var hint: root.keys[index] ?? ({})
      Layout.fillWidth: true
      Layout.preferredWidth: 1
      onActivated: root.picked(entry.hint.key)

      KeyHint {
        key: entry.hint.key ?? ""
        paired: true
        chars: MenuKeys.gutter(root.chars)
      }

      Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        text: entry.hint.desc ?? ""
      }
    }
  }
}
