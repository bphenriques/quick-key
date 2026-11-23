pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs

// A surface the keyboard opens (the menu, a plugin panel) at the screen edge: an optional bar at the edge, the card past it, and an optional input past the card (`inputOver`) or between it and the bar; a click elsewhere dismisses it.
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
      id: window
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
        // The bar by its surfaces: as islands, a click between them reaches the dismiss area too.
        Region {
          regions: Array.from({ length: islands.count }, (_, i) => islands.itemAt(i)?.region)
        }
        Region {
          item: inputSurface.visible ? inputSurface : null
        }
      }
      BackgroundEffect.blurRegion: Region {
        item: cardSurface
        radius: Config.theme.radius
        Region {
          regions: Array.from({ length: islands.count }, (_, i) => islands.itemAt(i)?.region)
        }
        Region {
          item: inputSurface.visible ? inputSurface : null
          radius: Config.theme.radius
        }
      }

      // Keys the body or the input leave reach the owner.
      FocusScope {
        id: frame
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => root.keyPressed(event)
        Keys.onReleased: event => root.keyReleased(event)

        // Each surface's distance from the screen's bottom, stacking up from it: the bar against it, then the card and the input in their order.
        QtObject {
          id: stack
          readonly property real margin: window.edgeMargin
          readonly property real gap: Config.theme.spacing / 2
          readonly property real past: bar.visible ? margin + bar.height + gap : margin
          readonly property bool between: inputSurface.visible && !root.inputOver
          readonly property real card: between ? past + inputSurface.height + gap : past
          readonly property real input: root.inputOver ? card + cardSurface.height + gap : past
        }

        // Over the card, so a tip on its items shows over it.
        Item {
          id: bar
          visible: root.barShown
          z: 1
          x: cardSurface.x
          y: frame.height - stack.margin - height
          width: cardSurface.width
          // At least a padded line, so a level's bar without the clock is as tall as the top level's and the body holds still.
          height: Math.max(barRow.implicitHeight, Metrics.line + 2 * Metrics.itemPaddingY) + Config.theme.padding / 2

          // One surface behind the row; with `menu.islands`, one behind each item its content lists in `islands`, and the statuses.
          Repeater {
            id: islands
            model: Config.menu.islands ? (barContent.item?.islands ?? []).concat(statusesContent.item ? [statusesContent.item] : []) : [barRow]

            Surface {
              id: island
              required property Item modelData
              // By the bar it sits on, so it follows the bar too.
              readonly property Region region: PlacedRegion {
                over: island
                at: Qt.point(bar.x + island.x, bar.y + island.y)
              }
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
          // Centred; the bar and the input follow it.
          x: (parent.width - width) / 2
          y: frame.height - stack.card - height
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
          y: frame.height - stack.input - height
          width: cardSurface.width
          height: inputContent.implicitHeight + Config.theme.padding

          Loader {
            id: inputContent
            anchors.verticalCenter: parent.verticalCenter
            anchors.left: parent.left
            anchors.right: parent.right
            // Inset as a row's content is, so its key column lines up with the body's keys.
            anchors.leftMargin: Config.theme.padding + Metrics.itemPaddingX
            anchors.rightMargin: Config.theme.padding + Metrics.itemPaddingX
            active: root.inputShown
            focus: root.inputFocused
            sourceComponent: root.input
          }
        }
      }
    }
  }
}
