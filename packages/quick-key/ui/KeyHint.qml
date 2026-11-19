import QtQuick

// The key that triggers an item, in a gutter of `chars` characters so a level's labels start together.
Item {
  id: root

  property var key
  property bool paired: false
  property int chars: 1

  implicitWidth: Metrics.cell * chars
  implicitHeight: label.implicitHeight

  Label {
    id: label
    tone: "primary"
    text: MenuKeys.label(root.key, root.paired)
  }
}
