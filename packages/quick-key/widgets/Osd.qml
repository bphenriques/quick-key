pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.builtins
import qs.services
import qs.ui

// A slim bar at the screen's right edge, on a change to any listed status or plugin, so it never reads as a notification.
Scope {
  id: root

  // What is or was last shown, a status or a plugin; kept while the window closes.
  property string kind: ""
  // The output it shows on, the focused one as a showing starts, so it never moves while shown.
  property string output: ""

  function show(newKind) {
    if (root.covered) return;
    if (!transient.shown) output = Compositor.focusedOutput;
    kind = newKind;
    transient.show();
  }

  Transient {
    id: transient
  }

  // A menu or panel open shows the value itself: no pop-up then, and one showing goes.
  readonly property bool covered: Panels.top !== null
  onCoveredChanged: if (covered) transient.hide()

  Fade {
    id: fade
    shown: transient.shown
  }

  // One per listed name, showing itself when its state changes; a service starts only for what is listed.
  Instantiator {
    model: Config.popups.show

    delegate: Scope {
      required property string modelData

      readonly property var status: Statuses.of(modelData)
      // What the status calls a change, else its look together: a toggle's glyph never moves, so its text says the change.
      readonly property string signature: JSON.stringify(status.change ?? [status.glyph, status.fields, status.meter, status.muted, status.popup, status.active, status.tone])

      // Its source has reported: its first value is state, the next ones changes.
      readonly property bool ready: status.ready
      property bool settled: false
      onReadyChanged: if (ready) Qt.callLater(() => settled = true)
      Component.onCompleted: if (ready) Qt.callLater(() => settled = true)
      onSignatureChanged: if (settled) root.show(modelData)
    }
  }

  LazyLoader {
    active: fade.loaded

    OverlayWindow {
      id: window

      // Named, so its size is known before the surface maps; left to the compositor, Qt would guess another.
      screen: Quickshell.screens.find(each => each.name === root.output) ?? Quickshell.screens[0]
      readonly property var status: Statuses.of(root.kind)
      readonly property bool metered: status.meter >= 0
      // Never a dim fallback: a status without a tone of its own reads normal.
      readonly property string tone: status.muted ? "dim" : status.tone || (status.active ? "primary" : "normal")

      // A level no longer than half its screen.
      readonly property real length: Math.min(Metrics.osdLength, screen.height / 2 || Metrics.osdLength)
      // At the right edge, centred along it.
      anchors.right: true
      margins.right: Math.min(Config.theme.edgeMargin, screen.width / 4, screen.height / 4)
      WlrLayershell.namespace: "quick-key-osd"
      // Blurred behind, as the menu is, so a translucent theme reads the same on every surface.
      BackgroundEffect.blurRegion: Region {
        item: window.shape
        radius: window.shape.radius
      }

      // What shows, a level or a pill.
      readonly property Item shape: metered ? bar : pill
      implicitWidth: shape.implicitWidth
      implicitHeight: shape.implicitHeight

      // A level: a bar, the level above the icon.
      Surface {
        id: bar
        opacity: fade.value
        width: implicitWidth
        height: implicitHeight
        visible: window.metered
        implicitWidth: Metrics.osdIconSize + 2 * Config.theme.padding
        implicitHeight: levelColumn.implicitHeight + 2 * Config.theme.padding

        // The wheel runs the pair action the status names; a pill adjusts nothing.
        WheelSteps {
          anchors.fill: parent
          hoverEnabled: true
          onContainsMouseChanged: transient.held = containsMouse
          onStepped: up => {
            if (window.status.adjust) Actions.builtin[window.status.adjust].run(up);
          }
        }

        Grid {
          id: levelColumn
          anchors.centerIn: parent
          spacing: Config.theme.padding
          columns: 1
          horizontalItemAlignment: Grid.AlignHCenter

          Meter {
            orientation: Qt.Vertical
            height: window.length
            tone: window.status.muted ? "dim" : "primary"
            value: window.metered ? window.status.meter : 0
          }

          Icon {
            size: Metrics.osdIconSize
            tone: window.tone
            glyph: window.status.glyph
          }
        }
      }

      // A state without a level: a pill with the icon and what it is now.
      Pill {
        id: pill
        opacity: fade.value
        width: implicitWidth
        height: implicitHeight
        visible: !window.metered
        padding: Config.theme.padding
        // The bar's radius, not the capsule: the two shapes swap as the kind changes, so they must agree.
        radius: Config.theme.radius

        Icon {
          tone: window.tone
          glyph: window.status.glyph
        }

        Label {
          // As wide as its widest value where the glyph alone says little, so the pill holds still as the value changes.
          Layout.preferredWidth: (window.status.popupWidth || window.status.popup.length) * Metrics.cell
          tone: window.tone
          text: window.status.popup
        }
      }
    }
  }
}
