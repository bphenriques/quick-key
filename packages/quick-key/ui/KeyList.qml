pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

// Keys and what each does, a row each across the menu's columns, as `?` lists the keys no row shows; a click is `picked`.
GridLayout {
  id: root

  // [{ key, desc }], a key being a name or a pair of names.
  property var keys: []
  readonly property int chars: Math.max(1, ...keys.map(hint => MenuKeys.label(hint.key, true).length))

  signal picked(var key)

  flow: GridLayout.LeftToRight
  columns: Config.menu.columns
  columnSpacing: Math.max(Config.theme.padding, Metrics.cell)
  rowSpacing: Config.theme.listSpacing

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
