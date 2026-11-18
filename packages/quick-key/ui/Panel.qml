pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// A surface the keyboard opens (the menu, a plugin's panel): a card at the bottom centre, an optional bar floating over it and an input under it, one open at a time; a click anywhere else dismisses it.
Scope {
  id: root

  property bool shown: false
  property string namespace
  property real width: Config.menu.width
  property bool barShown: false
  property Component bar
  property Component body
  property bool inputShown: false
  // Whether the input has the keys, else the body.
  property bool inputFocused: false
  property Component input

  signal dismissed
  // The keys the body's own focus leaves, to accept or not.
  signal keyPressed(var event)
  signal keyReleased(var event)
  // A right click on the card, beside what takes its own clicks.
  signal secondaryClicked

  // Hidden at once and then unloaded: torn down while still on screen, it would show its blur over nothing for a frame.
  onShownChanged: {
    if (shown) {
      Panels.current = root;
      internal.loaded = true;
    } else {
      Qt.callLater(() => internal.loaded = root.shown);
    }
  }

  QtObject {
    id: internal
    property bool loaded: false
  }

  Connections {
    target: Panels

    function onCurrentChanged() {
      if (root.shown && Panels.current !== root) root.dismissed();
    }
  }

  LazyLoader {
    id: dismiss
    active: internal.loaded

    Variants {
      model: Quickshell.screens

      DismissArea {
        required property var modelData
        screen: modelData
        visible: root.shown
        onDismissed: root.dismissed()
      }
    }
  }

  // Created after the dismiss areas, so it stacks above them on the same layer.
  LazyLoader {
    active: internal.loaded && dismiss.item !== null

    OverlayWindow {
      visible: root.shown
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
        Region {
          item: inputSurface.visible ? inputSurface : null
        }
      }
      BackgroundEffect.blurRegion: Region {
        item: card
        radius: Config.theme.radius
        Region {
          item: bar.visible ? bar : null
          radius: Config.theme.radius
        }
        Region {
          item: inputSurface.visible ? inputSurface : null
          radius: Config.theme.radius
        }
      }

      // Keys the body or the input leave reach the owner.
      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.keyPressed(event)
        Keys.onReleased: event => root.keyReleased(event)

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
          anchors.bottom: inputSurface.visible ? inputSurface.top : parent.bottom
          anchors.bottomMargin: inputSurface.visible ? Config.theme.spacing / 2 : Config.theme.edgeMargin
          width: root.width
          height: body.implicitHeight + 2 * Config.theme.padding

          MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.RightButton
            onClicked: root.secondaryClicked()
          }

          Loader {
            id: body
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: Config.theme.padding
            focus: !root.inputFocused
            sourceComponent: root.body
          }
        }

        // As the bar floats over the card, the input floats under it.
        Surface {
          id: inputSurface
          visible: root.inputShown
          anchors.horizontalCenter: parent.horizontalCenter
          anchors.bottom: parent.bottom
          anchors.bottomMargin: Config.theme.edgeMargin
          width: card.width
          height: inputContent.implicitHeight + Config.theme.padding

          Loader {
            id: inputContent
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Config.theme.padding
            anchors.rightMargin: Config.theme.padding
            active: root.inputShown
            focus: root.inputFocused
            sourceComponent: root.input
          }
        }
      }
    }
  }
}
