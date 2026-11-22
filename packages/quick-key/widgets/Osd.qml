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
    kind = newKind;
    transient.show();
  }

  Transient {
    id: transient
  }

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

      anchors.right: true
      margins.right: Config.theme.edgeMargin
      WlrLayershell.namespace: "osd"

      implicitWidth: metered ? bar.implicitWidth : pill.implicitWidth
      implicitHeight: metered ? bar.implicitHeight : pill.implicitHeight

      // A level: a vertical bar, the level above the icon.
      Surface {
        id: bar
        opacity: fade.value
        anchors.fill: parent
        visible: window.metered
        implicitWidth: Config.theme.osdIconSize + 2 * Config.theme.padding
        implicitHeight: levelColumn.implicitHeight + 2 * Config.theme.padding

        // The wheel runs the pair action the status names; a pill adjusts nothing.
        WheelSteps {
          anchors.fill: parent
          hoverEnabled: true
          onContainsMouseChanged: transient.held = containsMouse
          onStepped: up => {
            if (window.status && window.status.adjust) Actions.builtin[window.status.adjust].run(up);
          }
        }

        Column {
          id: levelColumn
          anchors.centerIn: parent
          spacing: Config.theme.padding

          Meter {
            anchors.horizontalCenter: parent.horizontalCenter
            orientation: Qt.Vertical
            height: Config.theme.osdLength
            tone: window.muted ? "dim" : "primary"
            value: window.metered ? window.status.meter() : 0
          }

          Icon {
            anchors.horizontalCenter: parent.horizontalCenter
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
        anchors.fill: parent
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
