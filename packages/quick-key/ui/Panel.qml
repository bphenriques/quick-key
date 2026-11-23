pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import QtQuick.Window
import Quickshell
import Quickshell.Wayland
import qs

// A surface the keyboard opens (the menu, a plugin's panel) at the screen's edge (`menu.edge`, `menu.align`): an optional bar at the edge, the card past it and an optional input, past the card (`inputOver`, a level's island) or between it and the bar; one shown at a time, its owner on top of Panels; a click anywhere else dismisses it.
Scope {
  id: root

  property bool shown: false
  property string namespace
  property real width: Config.menu.width
  property bool barShown: false
  property Component bar
  // The top level's right slot on the bar's right (Panels.statuses), for a plugin's panel.
  property bool statuses: false
  property Component body
  property bool inputShown: false
  property bool inputOver: false
  // The bar drawn as islands, one behind each item its content lists in `islands`, rather than as one surface.
  property bool islands: false
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
    active: internal.loaded && dismiss.item !== null

    OverlayWindow {
      visible: root.shown
      // The whole screen, so bodies of different sizes never resize the window: a resize shows the old size for a frame.
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      WlrLayershell.namespace: "quick-key-" + root.namespace
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
          item: bar.visible && !root.islands ? bar : null
          radius: Config.theme.radius
        }
        Region {
          regions: Array.from({ length: islandRegions.count }, (_, i) => islandRegions.objectAt(i))
        }
        Region {
          item: inputSurface.visible ? inputSurface : null
          radius: Config.theme.radius
        }
      }

      Instantiator {
        id: islandRegions
        model: islandsDrawn.count

        Region {
          required property int index
          readonly property Item island: islandsDrawn.count > index ? islandsDrawn.itemAt(index) : null
          item: island?.visible ? island : null
          radius: Config.theme.radius
        }
      }

      // Keys the body or the input leave reach the owner.
      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.keyPressed(event)
        Keys.onReleased: event => root.keyReleased(event)

        // Where the card and the input stack from, away from the edge: past the bar, else the edge.
        Item {
          id: base
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.bottom: Config.atTop ? undefined : bar.visible ? bar.top : parent.bottom
          anchors.top: !Config.atTop ? undefined : bar.visible ? bar.bottom : parent.top
          anchors.bottomMargin: bar.visible ? Config.theme.spacing / 2 : Config.menu.margin
          anchors.topMargin: bar.visible ? Config.theme.spacing / 2 : Config.menu.margin
        }

        // Over the card, so a tip on its items shows over it.
        Surface {
          id: bar
          visible: root.barShown
          z: 1
          anchors.horizontalCenter: card.horizontalCenter
          anchors.bottom: Config.atTop ? undefined : parent.bottom
          anchors.top: Config.atTop ? parent.top : undefined
          anchors.bottomMargin: Config.menu.margin
          anchors.topMargin: Config.menu.margin
          width: card.width
          // At least a title's line, so a level's bar without the clock is as tall as the top level's and the body holds still.
          height: Math.max(barRow.implicitHeight, Metrics.titleLine + 2 * Config.theme.itemPaddingY) + Config.theme.padding / 2
          // As islands, only what is behind each item shows.
          color: root.islands ? "transparent" : Tone.surface()
          border.width: root.islands ? 0 : Config.theme.borderWidth / Screen.devicePixelRatio

          Repeater {
            id: islandsDrawn
            model: root.islands ? barContent.item?.islands ?? [] : []

            Surface {
              required property Item modelData
              // Its item's place in the bar, read again as the item or its slot moves or resizes.
              readonly property rect box: modelData.visible && modelData.width + modelData.x + (modelData.parent?.x ?? 0) + (modelData.parent?.width ?? 0) >= 0 ? modelData.mapToItem(bar, 0, 0, modelData.width, modelData.height) : Qt.rect(0, 0, 0, 0)
              visible: box.width > 0
              x: box.x
              width: box.width
              height: bar.height
            }
          }

          RowLayout {
            id: barRow
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.leftMargin: Config.theme.padding
            anchors.rightMargin: Config.theme.padding
            spacing: Config.theme.spacing

            Loader {
              id: barContent
              Layout.fillWidth: true
              sourceComponent: root.bar
            }

            Loader {
              active: root.statuses
              sourceComponent: Panels.statuses
            }
          }
        }

        Surface {
          id: card
          // Along the edge as `menu.align` says; the bar and the input follow it.
          x: Config.menu.align === "left" ? Config.menu.margin : Config.menu.align === "right" ? parent.width - width - Config.menu.margin : (parent.width - width) / 2
          anchors.bottom: Config.atTop ? undefined : inputSurface.visible && !root.inputOver ? inputSurface.top : base.bottom
          anchors.top: !Config.atTop ? undefined : inputSurface.visible && !root.inputOver ? inputSurface.bottom : base.top
          anchors.bottomMargin: inputSurface.visible && !root.inputOver ? Config.theme.spacing / 2 : 0
          anchors.topMargin: inputSurface.visible && !root.inputOver ? Config.theme.spacing / 2 : 0
          // No wider than the screen leaves within its margins, whatever width a level asks for.
          width: Math.min(root.width, parent.width - 2 * Config.menu.margin)
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

        Surface {
          id: inputSurface
          visible: root.inputShown
          anchors.horizontalCenter: card.horizontalCenter
          anchors.bottom: Config.atTop ? undefined : root.inputOver ? card.top : base.bottom
          anchors.top: !Config.atTop ? undefined : root.inputOver ? card.bottom : base.top
          anchors.bottomMargin: root.inputOver ? Config.theme.spacing / 2 : 0
          anchors.topMargin: root.inputOver ? Config.theme.spacing / 2 : 0
          width: card.width
          height: inputContent.implicitHeight + Config.theme.padding

          Loader {
            id: inputContent
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            // Inset as a row's content is, so its key column lines up with the body's keys.
            anchors.leftMargin: Config.theme.padding + Config.theme.itemPaddingX
            anchors.rightMargin: Config.theme.padding + Config.theme.itemPaddingX
            active: root.inputShown
            focus: root.inputFocused
            sourceComponent: root.input
          }
        }
      }
    }
  }
}
