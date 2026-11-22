pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// The cards in their corner of the focused screen, the newest by the corner; only the cards take the pointer. Summoned, it takes the keys where it is, its bar where its pills sit.
Scope {
  id: view

  required property var plugin
  readonly property var settings: plugin.settings
  readonly property bool top: settings.corner.startsWith("top")
  readonly property bool right: settings.corner.endsWith("right")
  readonly property var cards: top ? plugin.shown : plugin.shown.slice().reverse()

  // A picture: an icon sent as a file (album art, a screenshot), else image data, which Quickshell serves as image://qsimage.
  function pictureOf(notification) {
    const file = plugin.fileOf(notification);
    return file ? "file://" + file : notification.image?.startsWith("image://qsimage") ? notification.image : "";
  }

  // An icon sent by its name, from the theme, at a glyph's size.
  function iconOf(notification) {
    const icon = plugin.iconOf(notification);
    return icon && !plugin.fileOf(notification) ? Quickshell.iconPath(icon, true) : "";
  }

  // The focused screen, which the cards follow while nothing holds them still.
  property var screen: null
  readonly property var focused: Quickshell.screens.find(screen => screen.name === Compositor.focusedOutput) ?? null
  onFocusedChanged: follow()
  Component.onCompleted: follow()

  function follow() {
    if (!plugin.still) screen = focused;
  }

  Connections {
    target: view.plugin

    function onStillChanged() {
      view.follow();
    }
  }

  Fade {
    id: fade
    // Under a fullscreen window, the held count shows nothing over it.
    shown: view.plugin.summoned || view.plugin.shown.length > 0 || view.plugin.held > 0 && !view.plugin.fullscreen
  }

  // A click beside the cards lets go of the keys; on the layer below theirs, so the cards keep their clicks.
  LazyLoader {
    active: view.plugin.summoned

    Variants {
      model: Quickshell.screens

      DismissArea {
        required property var modelData
        screen: modelData
        WlrLayershell.layer: WlrLayer.Top
        onDismissed: view.plugin.release()
      }
    }
  }

  LazyLoader {
    active: fade.loaded

    OverlayWindow {
      id: window

      screen: view.screen
      // As tall as the cards, so blocking it from screen capture hides them and nothing beside them.
      anchors.top: view.top
      anchors.bottom: !view.top
      anchors.right: view.right
      anchors.left: !view.right
      // In the top right, under the corner pills (recording) as they stack.
      margins.top: Config.theme.edgeMargin + (view.right ? CornerPills.order.length * (Metrics.line + 3 * Config.theme.spacing) : 0)
      margins.bottom: Config.theme.edgeMargin
      margins.right: Config.theme.edgeMargin
      margins.left: Config.theme.edgeMargin
      implicitWidth: view.settings.width
      implicitHeight: stack.implicitHeight
      WlrLayershell.namespace: "quick-key-notifications"
      WlrLayershell.keyboardFocus: view.plugin.summoned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      mask: Region {
        item: stack
      }

      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => event.accepted = view.plugin.key(MenuKeys.name(event))

        Column {
          id: stack
          width: parent.width
          spacing: Config.theme.spacing
          opacity: fade.value

          Ends {
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
              icon: notification ? view.iconOf(notification) : ""
              image: notification ? view.pictureOf(notification) : ""
              title: notification?.summary || notification?.appName || ""
              aside: notification?.gone ? view.plugin.words.closed : notification?.summary ? notification.appName : ""
              body: notification?.body ?? ""
              tone: notification && view.plugin.critical(notification) ? "alert" : ""
              dimmed: notification?.gone ?? false
              meter: typeof hint === "number" ? Math.max(0, Math.min(100, hint)) / 100 : -1
              meterText: meter >= 0 ? Math.round(meter * 100) + "%" : ""
              actions: view.plugin.actionsOf(notification)
              // Replying, the body takes a line and the prompt two, so the card keeps its height.
              lines: notification && notification === view.plugin.replying ? 1 : 2
              footer: !notification ? null : notification === view.plugin.replying ? reply : notification.id in view.plugin.sent ? sent : null
              actionSide: view.settings.actionSide
              key: String(view.plugin.shown.indexOf(notification) + 1)
              closeKey: "x"
              keysShown: view.plugin.summoned
              current: view.plugin.summoned && notification === view.plugin.picked
              onActivated: view.plugin.open(notification)
              onDismissed: notification.dismiss()
              onHoveredChanged: view.plugin.hold(hovered)

              // What was sent, as your side of the exchange, on the right.
              Component {
                id: sent

                RowLayout {
                  Item {
                    Layout.fillWidth: true
                  }

                  Bubble {
                    mine: true
                    maximumWidth: parent.width

                    Label {
                      Layout.fillWidth: true
                      elide: Text.ElideRight
                      text: view.plugin.sent[card.notification?.id] ?? ""
                    }
                  }
                }
              }
            }
          }

          Ends {
            visible: view.top
          }
        }
      }
    }
  }

  // The reply typed in the card: RET sends it, C-S-RET sends it and lets go, ESC clears it, then goes back to the card's keys; to a card closed meanwhile, RET copies it.
  Component {
    id: reply

    Prompt {
      id: prompt
      maxLines: 2
      placeholder: view.plugin.replying?.inlineReplyPlaceholder || Words.replyPrompt
      keys: text !== "" ? [{ key: "Escape", what: Words.clear, clickable: true }] : []
      onPicked: stepBack()
      onBack: view.plugin.endReply()
      Component.onCompleted: set(view.plugin.draftOf(view.plugin.replying))
      onTextChanged: view.plugin.keepDraft(view.plugin.replying, text)
      onKeyPressed: event => {
        const send = MenuKeys.sends(event);
        if (!send) return;
        event.accepted = true;
        if (view.plugin.replying?.gone) view.plugin.copyReply(text);
        else view.plugin.sendReply(text, send === "background");
      }
    }
  }

  // The side away from the corner: summoned, the keys; else those over the limit, those held, and the key that summons.
  component Ends: Item {
    width: parent.width
    implicitHeight: view.plugin.summoned ? bar.implicitHeight : pills.implicitHeight

    Surface {
      id: bar
      visible: view.plugin.summoned
      width: parent.width
      color: Tone.surface(1)
      implicitHeight: legend.implicitHeight + Config.theme.padding / 2

      KeyLegend {
        id: legend
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.leftMargin: Config.theme.padding
        keys: view.plugin.replying?.gone ? [{ key: "Return", what: Words.copy }] : view.plugin.replying ? [{ key: "Return", what: view.plugin.words.send }, { key: "Ctrl+Shift+Return", what: view.plugin.words.sendClose }] : view.plugin.shown.length === 0 ? [{ key: "Ctrl+p", what: view.plugin.paused ? view.plugin.words.resume : view.plugin.words.pause }] : [
          { key: "Return", what: Words.open },
          { key: "Ctrl+Shift+x", what: view.plugin.words.clear },
          { key: "Ctrl+p", what: view.plugin.paused ? view.plugin.words.resume : view.plugin.words.pause }
        ]
      }

      // None to show, or how many are of all there are, as a filter says it.
      Label {
        visible: text !== ""
        anchors.verticalCenter: parent.verticalCenter
        anchors.right: parent.right
        anchors.rightMargin: Config.theme.padding
        tone: "dim"
        text: view.plugin.shown.length === 0 ? view.plugin.words.none : view.plugin.more > 0 ? Words.rangeOf(view.plugin.first, view.plugin.shown.length, view.plugin.showable.length) : ""
      }
    }

    Row {
      id: pills
      visible: !view.plugin.summoned
      anchors.right: view.right ? parent.right : undefined
      spacing: Config.theme.spacing

      Pill {
        visible: view.settings.hint && view.plugin.shortcut !== ""

        KeyHint {
          anchors.verticalCenter: parent.verticalCenter
          key: view.plugin.shortcut
          chars: MenuKeys.label(view.plugin.shortcut).length
        }
      }

      Pill {
        visible: view.plugin.more > 0

        Label {
          text: "+" + view.plugin.more
        }
      }

      Pill {
        visible: view.plugin.held > 0 && !view.plugin.fullscreen

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

    // A click on a pill summons the cards, the held ones with them.
    MouseArea {
      anchors.fill: pills
      enabled: pills.visible
      onClicked: view.plugin.summon()
    }
  }
}
