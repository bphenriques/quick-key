pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.ui

// The cards in their corner of the focused screen, the newest by the corner; the window spans the screen's height, so it never resizes, and only the cards take the pointer.
Scope {
  id: view

  required property var plugin
  readonly property var settings: plugin.settings
  readonly property bool top: settings.corner.startsWith("top")
  readonly property bool right: settings.corner.endsWith("right")
  readonly property var cards: top ? plugin.shown : plugin.shown.slice().reverse()

  // Its picture, else its app's icon by path or name; else the card's glyph.
  function imageOf(notification) {
    const file = notification.image || notification.appIcon;
    if (!file) return "";
    return file.startsWith("/") ? "file://" + file : file.includes(":/") ? file : Quickshell.iconPath(file, true);
  }

  Fade {
    id: fade
    shown: view.plugin.shown.length > 0 || view.plugin.held > 0
  }

  LazyLoader {
    active: fade.loaded

    OverlayWindow {
      id: window

      anchors.top: true
      anchors.bottom: true
      anchors.right: view.right
      anchors.left: !view.right
      margins.right: Config.theme.edgeMargin
      margins.left: Config.theme.edgeMargin
      implicitWidth: view.settings.width
      WlrLayershell.namespace: "quick-key-notifications"
      mask: Region {
        item: stack
      }

      Column {
        id: stack
        width: parent.width
        // In the top right, under the corner pills (recording) as they stack.
        y: view.top ? Config.theme.edgeMargin + (view.right ? CornerPills.order.length * (Metrics.line + 3 * Config.theme.spacing) : 0) : window.height - height - Config.theme.edgeMargin
        spacing: Config.theme.spacing
        opacity: fade.value

        Pills {
          visible: !view.top
        }

        Repeater {
          model: view.cards.length

          Card {
            id: card
            required property int index
            readonly property var notification: view.cards[index] ?? null
            readonly property var hint: notification?.hints.value

            width: stack.width
            glyph: Glyphs.notifications
            image: notification ? view.imageOf(notification) : ""
            title: notification?.summary || notification?.appName || ""
            aside: notification?.summary ? notification.appName : ""
            body: notification?.body ?? ""
            tone: notification && view.plugin.critical(notification) ? "alert" : ""
            meter: typeof hint === "number" ? Math.max(0, Math.min(100, hint)) / 100 : -1
            meterText: meter >= 0 ? Math.round(meter * 100) + "%" : ""
            actions: Array.from(notification?.actions ?? []).filter(action => action.identifier !== "default").map(action => ({ desc: action.text, run: () => action.invoke() }))
            actionSide: view.settings.actionSide
            onActivated: view.plugin.open(notification)
            onDismissed: notification.dismiss()
            onHoveredChanged: view.plugin.hold(notification, hovered)
          }
        }

        Pills {
          visible: view.top
        }
      }
    }
  }

  // Those over the limit, and those held while paused or under a fullscreen window, on the side away from the corner.
  component Pills: Row {
    anchors.right: view.right ? parent.right : undefined
    spacing: Config.theme.spacing

    Pill {
      visible: view.plugin.more > 0

      Label {
        text: "+" + view.plugin.more
      }
    }

    Pill {
      visible: view.plugin.held > 0

      Icon {
        anchors.verticalCenter: parent.verticalCenter
        glyph: Glyphs.notificationsPaused
      }

      Label {
        anchors.verticalCenter: parent.verticalCenter
        text: view.plugin.held
      }
    }
  }
}
