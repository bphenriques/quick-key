pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// A pill in the top right corner of every screen while `shown`, fading in and out, stacked under the pills already showing.
Scope {
  id: root

  property bool shown: false
  property string tone: ""
  property string namespace
  default property Component content
  readonly property bool hovered: internal.hovered
  // As tall as it draws, for CornerPills to stack the rest under it.
  property real height: 0

  signal clicked

  QtObject {
    id: internal

    property bool hovered: false
  }

  Fade {
    id: fade
    shown: root.shown
    onLoadedChanged: loaded ? CornerPills.add(root) : CornerPills.remove(root)
  }

  Component.onDestruction: CornerPills.remove(root)

  LazyLoader {
    active: fade.loaded

    Variants {
      model: Quickshell.screens

      OverlayWindow {
        required property var modelData
        screen: modelData

        anchors.top: true
        anchors.right: true
        margins.top: Config.popups.margin + CornerPills.offset(root)
        margins.right: Config.popups.margin
        onImplicitHeightChanged: root.height = implicitHeight
        Component.onCompleted: root.height = implicitHeight
        WlrLayershell.namespace: "quick-key-" + root.namespace
        // Blurred behind, as the menu is, so a translucent theme reads the same on every surface.
        BackgroundEffect.blurRegion: Region {
          item: pill
          radius: pill.radius
        }

        implicitWidth: pill.implicitWidth
        implicitHeight: pill.implicitHeight

        Pill {
          id: pill
          tone: root.tone
          opacity: fade.value
          // Sliding, in from the right.
          transform: Translate {
            x: fade.offset
          }
          anchors.fill: parent

          Loader {
            anchors.verticalCenter: parent.verticalCenter
            sourceComponent: root.content
          }
        }

        MouseArea {
          anchors.fill: pill
          hoverEnabled: true
          onContainsMouseChanged: internal.hovered = containsMouse
          onClicked: root.clicked()
        }
      }
    }
  }
}
