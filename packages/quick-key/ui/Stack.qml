pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import "places.js" as Places

// A surface the keyboard opens (the menu, a plugin panel): its islands, listed top to bottom, stacked up from the screen's edge and centred; a click elsewhere dismisses it.
Scope {
  id: root

  property bool shown: false
  property string namespace
  property real width
  // The island the keys go to, by name.
  property string focus
  property list<Island> islands
  // The width every island takes: `width`, no wider than the screen leaves within its margins.
  readonly property real room: window.item ? Math.min(width, window.item.width - 2 * window.item.edgeMargin) : width

  signal dismissed
  // The keys the focused island leaves, to accept or not.
  signal keyPressed(var event)
  signal keyReleased(var event)

  // Hidden at once and then unloaded: torn down while still on screen, it would show its blur over nothing for a frame.
  onShownChanged: {
    if (shown) internal.loaded = true;
    else Qt.callLater(() => internal.loaded = root.shown);
  }

  QtObject {
    id: internal
    property bool loaded: false
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
    id: window
    active: internal.loaded && dismiss.item !== null

    OverlayWindow {
      id: overlay
      visible: root.shown
      // The whole screen, so islands of different sizes never resize the window: a resize shows the old size for a frame.
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      WlrLayershell.namespace: "quick-key-" + root.namespace
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      // Clicks beside the islands reach the dismiss area below.
      mask: Region {
        regions: frame.surfaces.map(island => island?.mask ?? null)
      }
      BackgroundEffect.blurRegion: Region {
        regions: frame.surfaces.map(island => island?.blur ?? null)
      }

      // Keys the focused island leaves reach the owner.
      FocusScope {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.keyPressed(event)
        Keys.onReleased: event => root.keyReleased(event)

        // Read again once every island is made: a binding that read one before it was made does not know it came.
        property int made: 0
        readonly property var surfaces: {
          void made;
          return Array.from({ length: islands.count }, (_, i) => islands.itemAt(i));
        }
        readonly property var places: Places.of(surfaces.map(island => island?.natural ?? 0), surfaces.map(island => island?.visible ?? false),
          surfaces.findIndex(island => island?.modelData.cut ?? false), height, overlay.edgeMargin, Config.theme.spacing / 2)

        Repeater {
          id: islands
          model: root.islands
          onItemAdded: frame.made++

          Item {
            id: island
            required property Island modelData
            required property int index
            readonly property real side: Config.theme.padding + modelData.inset
            readonly property real own: content.implicitHeight + 2 * modelData.padding
            readonly property real fit: Math.max(modelData.minimumHeight, own)
            readonly property real natural: Math.min(modelData.maximumHeight, Math.max(fit, held))
            // The tallest it has been while its holdKey stays, once laid out, so a height it has only for a moment is not kept.
            property real held: 0
            readonly property var holdKey: modelData.holdKey
            onHoldKeyChanged: {
              held = 0;
              hold.restart();
            }
            onFitChanged: if (modelData.holdKey) hold.restart()
            Component.onCompleted: if (modelData.holdKey) hold.restart()

            Timer {
              id: hold
              interval: 100
              onTriggered: island.held = island.modelData.holdKey ? Math.max(island.held, island.fit) : 0
            }
            readonly property var place: frame.places[index] ?? ({ y: 0, height: 0 })
            readonly property Region mask: Region {
              item: island.visible && !island.modelData.split ? island : null
              regions: parts.regions
            }
            readonly property Region blur: Region {
              item: island.visible && !island.modelData.split ? island : null
              radius: Config.theme.radius
              regions: parts.regions
            }
            visible: modelData.shown
            // Centred, on whole pixels, so a layer inside (a faded conversation) is not resampled.
            x: Math.round((frame.width - width) / 2)
            y: Math.round(place.y)
            width: modelData.width < 0 ? root.room : Math.min(modelData.width, overlay.width - 2 * overlay.edgeMargin)
            height: place.height
            clip: own > height

            Surface {
              anchors.fill: parent
              visible: !island.modelData.split
            }

            // Split, a surface behind each part, by the island it sits on, so it follows the island too.
            Repeater {
              id: parts
              property int made: 0
              readonly property var regions: {
                void made;
                return Array.from({ length: count }, (_, i) => itemAt(i)?.region);
              }
              onItemAdded: made++
              model: island.modelData.split ? content.item?.parts ?? [] : []

              Surface {
                id: part
                required property Item modelData
                readonly property Region region: PlacedRegion {
                  over: part
                  at: Qt.point(island.x + part.x, island.y + part.y)
                }
                visible: modelData.visible && modelData.width > 0
                // Its item's place in the content, each holder's offset up to it, read again as any moves; widened by the island's padding, so the outer parts meet its edges.
                x: {
                  let x = content.x;
                  for (let item = modelData; item && item !== content; item = item.parent)
                    x += item.x;
                  return x - island.side;
                }
                width: modelData.width + 2 * island.side
                height: island.height
              }
            }

            MouseArea {
              anchors.fill: parent
              acceptedButtons: Qt.LeftButton | Qt.RightButton
              onClicked: mouse => mouse.button === Qt.RightButton ? island.modelData.secondaryClicked() : island.modelData.clicked()
            }

            Loader {
              id: content
              anchors.verticalCenter: parent.verticalCenter
              // Held or kept taller than it is, against the screen's edge.
              anchors.verticalCenterOffset: Math.max(0, island.height - island.own) / 2
              anchors.left: parent.left
              anchors.right: parent.right
              anchors.leftMargin: island.side
              anchors.rightMargin: island.side
              focus: island.modelData.name === root.focus
              sourceComponent: island.modelData.content
            }
          }
        }
      }
    }
  }
}
