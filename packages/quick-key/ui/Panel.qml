pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// A surface the keyboard opens (the menu, a plugin's panel): a card at the bottom centre with an optional bar floating over it, one open at a time; a click anywhere else dismisses it.
Scope {
  id: root

  property bool shown: false
  property string namespace
  property real width: Config.menu.width
  property bool barShown: false
  property Component bar
  property Component body

  signal dismissed
  // The keys the body's own focus leaves, to accept or not.
  signal keyPressed(var event)
  signal keyReleased(var event)
  // A right click on the card, beside what takes its own clicks.
  signal secondaryClicked

  onShownChanged: if (shown) Panels.current = root

  Connections {
    target: Panels

    function onCurrentChanged() {
      if (root.shown && Panels.current !== root) root.dismissed();
    }
  }

  LazyLoader {
    id: dismiss
    active: root.shown

    Variants {
      model: Quickshell.screens

      DismissArea {
        required property var modelData
        screen: modelData
        onDismissed: root.dismissed()
      }
    }
  }

  // Created after the dismiss areas, so it stacks above them on the same layer.
  LazyLoader {
    active: root.shown && dismiss.item !== null

    OverlayWindow {
      // The whole screen, so bodies of different sizes never resize the window: a resize shows the old size for a frame.
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      WlrLayershell.namespace: root.namespace
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      // Clicks beside the bar and the card reach the dismiss area below.
      mask: Region {
        item: card
        Region {
          item: bar.visible ? bar : null
        }
      }
      BackgroundEffect.blurRegion: Region {
        item: card
        radius: Config.theme.radius
        Region {
          item: bar.visible ? bar : null
          radius: Config.theme.radius
        }
      }

      Surface {
        id: bar
        visible: root.barShown
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: card.top
        anchors.bottomMargin: Config.theme.spacing / 2
        width: card.width
        height: barContent.implicitHeight + Config.theme.padding / 2

        Loader {
          id: barContent
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.leftMargin: Config.theme.padding
          anchors.rightMargin: Config.theme.padding
          sourceComponent: root.bar
        }
      }

      Surface {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.theme.edgeMargin
        width: root.width
        height: body.implicitHeight + 2 * Config.theme.padding

        MouseArea {
          anchors.fill: parent
          acceptedButtons: Qt.RightButton
          onClicked: root.secondaryClicked()
        }

        FocusScope {
          anchors.fill: parent
          focus: true
          Keys.onPressed: event => root.keyPressed(event)
          Keys.onReleased: event => root.keyReleased(event)

          Loader {
            id: body
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Config.theme.padding
            focus: true
            sourceComponent: root.body
          }
        }
      }
    }
  }
}
