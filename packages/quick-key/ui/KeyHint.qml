import QtQuick

// The key that triggers an item, in a gutter of `chars` characters, so a level's labels start together, and never narrower than the key.
Item {
  id: root

  property var key
  property bool paired: false
  property int chars: 1
  // Dim while what it sits on does not have the keys.
  property bool live: true

  implicitWidth: Metrics.cell * Math.max(chars, label.text.length)
  implicitHeight: label.implicitHeight

  Label {
    id: label
    tone: root.live ? "primary" : "dim"
    text: MenuKeys.label(root.key, root.paired)
  }
}
