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
        item: cardSurface
        Region {
          item: bar.visible && !root.islands ? bar : null
        }
        // As islands, a click between them reaches the dismiss area too.
        Region {
          regions: Array.from({ length: islandRegions.count }, (_, i) => islandRegions.objectAt(i))
        }
        Region {
          item: inputSurface.visible ? inputSurface : null
        }
      }
      BackgroundEffect.blurRegion: Region {
        item: cardSurface
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

        // Each island by the bar it sits on, so it follows the bar too.
        PlacedRegion {
          required property int index
          over: islandsDrawn.count > index ? islandsDrawn.itemAt(index) : null
          at: Qt.point(bar.x + (over?.x ?? 0), bar.y + (over?.y ?? 0))
        }
      }

      // Keys the body or the input leave reach the owner.
      FocusScope {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.keyPressed(event)
        Keys.onReleased: event => root.keyReleased(event)

        // Each surface's distance from the screen's edge, stacking away from it: the bar against it, then the card and the input in their order; `along` places a distance at either edge, the one place the top edge mirrors.
        QtObject {
          id: stack
          // The margin set, but no more than a quarter of the screen, so a large one never pushes the menu off a small screen.
          readonly property real margin: Math.min(Config.menu.margin, frame.width / 4, frame.height / 4)
          readonly property real gap: Config.theme.spacing / 2
          readonly property real past: bar.visible ? margin + bar.height + gap : margin
          readonly property bool between: inputSurface.visible && !root.inputOver
          readonly property real card: between ? past + inputSurface.height + gap : past
          readonly property real input: root.inputOver ? card + cardSurface.height + gap : past

          function along(distance, height) {
            return Config.atTop ? distance : frame.height - distance - height;
          }
        }

        // Over the card, so a tip on its items shows over it.
        Surface {
          id: bar
          visible: root.barShown
          z: 1
          x: cardSurface.x
          y: stack.along(stack.margin, height)
          width: cardSurface.width
          // At least a title's line, so a level's bar without the clock is as tall as the top level's and the body holds still.
          height: Math.max(barRow.implicitHeight, Metrics.titleLine + 2 * Config.theme.itemPaddingY) + Config.theme.padding / 2
          // As islands, only what is behind each item shows.
          color: root.islands ? "transparent" : Tone.surface()
          border.width: root.islands ? 0 : Config.theme.borderWidth / Screen.devicePixelRatio

          Repeater {
            id: islandsDrawn
            // What its content lists, and the statuses Panel adds on the right.
            model: root.islands ? (barContent.item?.islands ?? []).concat(statusesContent.item ? [statusesContent.item] : []) : []

            Surface {
              required property Item modelData
              visible: modelData.visible && modelData.width > 0
              // Its item's place in the bar, each holder's offset up to the bar's row, read again as any moves; widened by the bar's padding, so the outer islands meet the card's edges.
              x: {
                let x = barRow.x;
                for (let item = modelData; item && item !== barRow; item = item.parent)
                  x += item.x;
                return x - Config.theme.padding;
              }
              width: modelData.width + 2 * Config.theme.padding
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
              id: statusesContent
              // Hidden too while inactive, or the row keeps a gap for it.
              visible: root.statuses
              active: root.statuses
              sourceComponent: Panels.statuses
            }
          }
        }

        Surface {
          id: cardSurface
          // Along the edge as `menu.align` says; the bar and the input follow it.
          x: Config.menu.align === "left" ? stack.margin : Config.menu.align === "right" ? parent.width - width - stack.margin : (parent.width - width) / 2
          y: stack.along(stack.card, height)
          // No wider than the screen leaves within its margins, whatever width a level asks for.
          width: Math.min(root.width, parent.width - 2 * stack.margin)
          // No taller than the screen leaves past what stacks before it, cut only when it must be.
          height: Math.min(body.implicitHeight + 2 * Config.theme.padding, frame.height - stack.card - stack.margin)
          clip: body.implicitHeight + 2 * Config.theme.padding > height

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
          x: cardSurface.x
          y: stack.along(stack.input, height)
          width: cardSurface.width
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
