pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.builtins
import qs.services
import qs.ui

// A slim bar at the right edge on a change to any listed status or plugin, so it never reads as a notification.
Scope {
  id: root

  // What is or was last shown, a status or a plugin; kept while the window closes.
  property string kind: ""

  function show(newKind) {
    if (root.covered) return;
    kind = newKind;
    transient.show();
  }

  Transient {
    id: transient
  }

  // A menu or panel open at its own edge shows the value itself: no pop-up then, and one showing goes.
  readonly property bool covered: Panels.top !== null && Config.popups.position === Config.menu.edge
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

      readonly property var status: Statuses.builtin[modelData] ?? null
      readonly property var plugin: status === null ? Plugins.get(modelData) : null
      readonly property var fields: status ? status.fields((id, name) => name) : ({})
      // What the status calls a change (change()), else glyph, fields, meter, muted and text together: a toggle's glyph never moves, so its text says the change.
      readonly property string signature: JSON.stringify(status
        ? status.change ? [status.change()] : [status.glyph(), fields, status.meter ? status.meter() : -1, status.muted ? status.muted() : false, status.popup ? status.popup() : Statuses.value(status, fields).text]
        : plugin ? [plugin.glyph, plugin.text, plugin.detail, plugin.active, plugin.tone] : [])

      // Its source has reported: its first value is state, the next ones changes.
      readonly property bool ready: status ? !status.ready || status.ready() : !!plugin && (!plugin.settings.watch && !plugin.settings.read && !plugin.settings.file || Object.keys(plugin.state).length > 0)
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

      readonly property var status: Statuses.builtin[root.kind] ?? null
      readonly property var plugin: Plugins.get(root.kind)
      readonly property var fields: status ? status.fields((id, name) => name) : ({})
      readonly property bool metered: status !== null && !!status.meter && status.meter() >= 0
      readonly property bool muted: status !== null && !!status.muted && status.muted()
      // Never a dim fallback: a status without a tone of its own reads normal.
      readonly property string tone: muted ? "dim" : status ? ((status.tone ? status.tone() : "") || "normal") : plugin ? (plugin.tone || (plugin.active ? "primary" : "normal")) : "normal"
      readonly property string glyph: status ? status.glyph() : plugin ? plugin.glyph : ""
      readonly property string text: status ? (status.popup ? status.popup() : Statuses.value(status, fields).text) : plugin ? [plugin.text, plugin.detail].filter(part => part).join(" ") : ""

      // At the edge `popups.position` names, centred along it; at the top or bottom a level reads across.
      readonly property bool across: Config.popups.position === "top" || Config.popups.position === "bottom"
      // Sliding, in from the edge it sits at.
      readonly property real room: Math.min(fade.distance, Config.popups.margin)
      readonly property real left: (1 - fade.value) * room
      readonly property point slide: Qt.point(Config.popups.position === "right" ? left : Config.popups.position === "left" ? -left : 0, Config.popups.position === "bottom" ? left : Config.popups.position === "top" ? -left : 0)
      // A level no longer than half its screen.
      readonly property real length: Math.min(Config.theme.osdLength, (across ? screen.width : screen.height) / 2 || Config.theme.osdLength)
      anchors.right: Config.popups.position === "right"
      anchors.left: Config.popups.position === "left"
      anchors.top: Config.popups.position === "top"
      anchors.bottom: Config.popups.position === "bottom"
      // Larger by the room a slide needs on its edge's side, the margin smaller by as much.
      margins.right: Config.popups.margin - (Config.popups.position === "right" ? room : 0)
      margins.left: Config.popups.margin - (Config.popups.position === "left" ? room : 0)
      margins.top: Config.popups.margin - (Config.popups.position === "top" ? room : 0)
      margins.bottom: Config.popups.margin - (Config.popups.position === "bottom" ? room : 0)
      WlrLayershell.namespace: "quick-key-osd"
      // Blurred behind, as the menu is, so a translucent theme reads the same on every surface.
      BackgroundEffect.blurRegion: Region {
        item: window.shape
        radius: window.shape.radius
      }

      // What shows, a level or a pill, placed within the window past the room left for a slide, and moved itself while sliding so its blur moves with it.
      readonly property Item shape: metered ? bar : pill
      readonly property point at: Qt.point((Config.popups.position === "left" ? room : 0) + slide.x, (Config.popups.position === "top" ? room : 0) + slide.y)
      implicitWidth: shape.implicitWidth + (across ? 0 : room)
      implicitHeight: shape.implicitHeight + (across ? room : 0)

      // A level: a bar, the level above the icon, or after it when it reads across.
      Surface {
        id: bar
        opacity: fade.value
        x: window.at.x
        y: window.at.y
        width: implicitWidth
        height: implicitHeight
        visible: window.metered
        implicitWidth: (window.across ? levelColumn.implicitWidth : Config.theme.osdIconSize) + 2 * Config.theme.padding
        implicitHeight: (window.across ? Config.theme.osdIconSize : levelColumn.implicitHeight) + 2 * Config.theme.padding

        // The wheel runs the pair action the status names; a pill adjusts nothing.
        WheelSteps {
          anchors.fill: parent
          hoverEnabled: true
          onContainsMouseChanged: transient.held = containsMouse
          onStepped: up => {
            if (window.status && window.status.adjust) Actions.builtin[window.status.adjust].run(up);
          }
        }

        Grid {
          id: levelColumn
          anchors.centerIn: parent
          spacing: Config.theme.padding
          columns: window.across ? 2 : 1
          // Across, the icon first, as on a row.
          layoutDirection: window.across ? Qt.RightToLeft : Qt.LeftToRight
          horizontalItemAlignment: Grid.AlignHCenter
          verticalItemAlignment: Grid.AlignVCenter

          Meter {
            orientation: window.across ? Qt.Horizontal : Qt.Vertical
            width: window.across ? window.length : implicitWidth
            height: window.across ? implicitHeight : window.length
            tone: window.muted ? "dim" : "primary"
            value: window.metered ? window.status.meter() : 0
          }

          Icon {
            size: Config.theme.osdIconSize
            tone: window.tone
            glyph: window.glyph
          }
        }
      }

      // A state without a level: a pill with the icon and what it is now.
      Pill {
        id: pill
        opacity: fade.value
        x: window.at.x
        y: window.at.y
        width: implicitWidth
        height: implicitHeight
        visible: !window.metered
        padding: Config.theme.padding
        // The bar's radius, not the capsule: the two shapes swap as the kind changes, so they must agree.
        radius: Config.theme.radius

        Icon {
          anchors.verticalCenter: parent.verticalCenter
          tone: window.tone
          glyph: window.glyph
        }

        Label {
          id: value
          anchors.verticalCenter: parent.verticalCenter
          // As wide as its widest value where the glyph alone says little, so the pill holds still as the value changes.
          width: (window.status && window.status.popupWidth ? window.status.popupWidth() : window.text.length) * Metrics.cell
          tone: window.tone
          text: window.text
        }
      }
    }
  }
}
