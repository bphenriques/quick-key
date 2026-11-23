pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs

// A pill in the top-right corner of every screen while `shown`, fading in and out, stacked under the pills already showing.
Scope {
  id: root

  property bool shown: false
  property string tone: ""
  property string namespace
  default property Component content
  readonly property bool hovered: internal.hovered
  // As tall as it draws with the gap after it, for CornerPills to stack the rest under it.
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
        id: window
        required property var modelData
        screen: modelData

        // Top right, as the cards are by default.
        anchors.top: true
        anchors.right: true
        readonly property real margin: Math.min(Config.theme.edgeMargin, modelData.width / 4, modelData.height / 4)
        margins.top: margin + CornerPills.offset(root)
        // Larger by the room a slide needs on the right, the margin smaller by as much.
        readonly property real room: Math.min(fade.distance, margin)
        margins.right: margin - room
        onImplicitHeightChanged: root.height = implicitHeight + Config.theme.spacing
        Component.onCompleted: root.height = implicitHeight + Config.theme.spacing
        WlrLayershell.namespace: "quick-key-" + root.namespace
        // Blurred behind, as the menu is, so a translucent theme reads the same on every surface.
        BackgroundEffect.blurRegion: Region {
          item: pill
          radius: pill.radius
        }

        implicitWidth: pill.implicitWidth + room
        implicitHeight: pill.implicitHeight

        Pill {
          id: pill
          tone: root.tone
          opacity: fade.value
          // Sliding, in from the right, within the room left for it, moved itself so its blur moves with it.
          x: (1 - fade.value) * window.room
          width: implicitWidth
          height: parent.height

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
