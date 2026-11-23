pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts

// Keys a level takes beyond its rows, on one line: each key as KeyHint shows it, then what it does; a single key also takes a click.
RowLayout {
  id: root

  // [{ key, what, clickable }], a key being a name or a pair of names (["Left", "Right"]).
  property var keys: []
  // Each entry's, as a row's; 0 to sit on a line of text.
  property real verticalPadding: Metrics.itemPaddingY

  signal picked(var key)

  // No spacing: each entry's own padding already spaces them.
  spacing: 0

  Repeater {
    model: root.keys.length

    // A click does what the key does, where that is one thing (`clickable`): a pair names no one key.
    ListItem {
      id: entry
      required property int index
      readonly property var hint: root.keys[index] ?? ({})

      enabled: !!hint.clickable
      verticalPadding: root.verticalPadding
      dimsWhenDisabled: false
      onActivated: root.picked(entry.hint.key)

      KeyHint {
        key: entry.hint.key ?? ""
        paired: true
      }

      Label {
        tone: "dim"
        text: entry.hint.what ?? ""
      }
    }
  }
}
