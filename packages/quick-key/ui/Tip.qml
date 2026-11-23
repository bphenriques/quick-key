import QtQuick
import qs

// What the pointer rests on, named above it after a moment: an icon alone (a tray app) says nothing to a mouse.
Surface {
  id: root

  property bool hovered: false
  property string text

  Timer {
    id: rest
    property bool done: false
    interval: 500
    running: root.hovered && !done
    onTriggered: done = true
  }

  Fade {
    id: fade
    shown: root.hovered && rest.done
  }

  onHoveredChanged: if (!hovered) rest.done = false

  visible: fade.loaded && text !== ""
  opacity: fade.value
  width: label.implicitWidth + 2 * Config.theme.itemPaddingX
  height: label.implicitHeight + 2 * Config.theme.itemPaddingY
  radius: Config.theme.itemRadius
  anchors.horizontalCenter: parent.horizontalCenter
  // Away from the edge the menu sits at, so it never leaves the screen.
  anchors.bottom: Config.atTop ? undefined : parent.top
  anchors.top: Config.atTop ? parent.bottom : undefined
  anchors.bottomMargin: Config.theme.spacing
  anchors.topMargin: Config.theme.spacing

  Label {
    id: label
    anchors.centerIn: parent
    text: root.text
  }
}
