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
    shown: view.plugin.summoned || view.plugin.shown.length > 0 || view.plugin.held > 0
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
        // Gone with the window, a hover it never saw end would hold the cards for good.
        Component.onDestruction: view.plugin.hold(false)
        Keys.onPressed: event => event.accepted = view.plugin.key(MenuKeys.name(event))

        Column {
          id: stack
          width: parent.width
          spacing: Config.theme.spacing
          opacity: fade.value

          // Over the whole stack, its gaps too, so moving between cards never lets go.
          HoverHandler {
            onHoveredChanged: view.plugin.hold(hovered)
          }

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
              monochrome: Config.theme.monochromeTray
              icon: notification ? view.iconOf(notification) : ""
              image: notification ? view.pictureOf(notification) : ""
              title: notification?.summary || notification?.appName || ""
              // The app, unless the title already says it, and when it came once it has waited.
              aside: !notification ? "" : [notification.appName.toLowerCase() === title.toLowerCase() ? "" : notification.appName, view.plugin.ageOf(notification)].filter(part => part).join(" · ")
              body: notification?.body ?? ""
              tone: notification && view.plugin.critical(notification) ? "alert" : ""
              dimmed: notification?.gone ?? false
              meter: typeof hint === "number" ? Math.max(0, Math.min(100, hint)) / 100 : -1
              meterText: meter >= 0 ? Math.round(meter * 100) + "%" : ""
              actions: view.plugin.actionsOf(notification)
              footer: !notification ? null : notification === view.plugin.replying ? reply : notification.id in view.plugin.sent ? sent : null
              actionSide: view.settings.actionSide
              // Its place among all, while a digit reaches it.
              readonly property int place: view.plugin.showable.indexOf(notification)
              key: place >= 0 && place < 9 ? String(place + 1) : ""
              closeKey: "x"
              // Replying, the prompt has the keys: the others would type.
              keysShown: view.plugin.summoned && !view.plugin.replying
              current: view.plugin.summoned && notification === view.plugin.picked
              onActivated: view.plugin.open(notification)
              onDismissed: notification.dismiss()

              // What was sent, one dim line in the actions' place, so the card never grows.
              Component {
                id: sent

                Label {
                  elide: Text.ElideRight
                  tone: "dim"
                  // In the text's column, as the prompt's glyph takes the icon's.
                  leftPadding: Config.theme.iconSize + Config.theme.spacing
                  text: view.plugin.words.you + (view.plugin.sent[card.notification?.id] ?? "")
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
      // One line, scrolling, in the actions' place: the card keeps its height.
      maxLines: 1
      placeholder: view.plugin.replying?.inlineReplyPlaceholder || Words.replyPrompt
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

    // Summoned: the keys the state changes on the left, what it reports on the right; `?` lists every key in its place.
    Surface {
      id: bar
      visible: view.plugin.summoned
      width: parent.width
      color: Tone.surface(1)
      implicitHeight: (view.plugin.help ? list.implicitHeight : barRow.implicitHeight) + Config.theme.padding / 2

      KeyList {
        id: list
        // One column: the stack is a card wide.
        columns: 1
        visible: view.plugin.help
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Config.theme.padding - Config.theme.itemPaddingX
        anchors.rightMargin: Config.theme.padding
        keys: view.plugin.keys
      }

      RowLayout {
        id: barRow
        visible: !view.plugin.help
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        // The keys' own padding, so they line up with the cards' digits.
        anchors.leftMargin: Config.theme.padding - Config.theme.itemPaddingX
        anchors.rightMargin: Config.theme.padding
        spacing: Config.theme.spacing

        KeyLegend {
          Layout.fillWidth: true
          clip: true
          keys: view.plugin.replying?.gone ? [{ key: "Return", what: view.plugin.words.copyReply }]
            : view.plugin.replying ? [{ key: "Return", what: view.plugin.words.send }].concat(view.plugin.draftOf(view.plugin.replying) !== "" ? [{ key: "Escape", what: Words.clear }] : [])
            : [{ key: "Ctrl+p", what: view.plugin.paused ? view.plugin.words.resume : view.plugin.words.pause }, { key: "?", what: Words.help }]
        }

        Label {
          visible: text !== ""
          tone: view.plugin.replying?.gone ? "warning" : "dim"
          text: view.plugin.replying?.gone ? view.plugin.words.closedBySender : view.plugin.replying ? "" : view.plugin.shown.length === 0 ? view.plugin.words.none : view.plugin.more > 0 ? "+" + view.plugin.more : ""
        }
      }
    }

    Row {
      id: pills
      visible: !view.plugin.summoned
      anchors.right: view.right ? parent.right : undefined
      spacing: Config.theme.spacing

      Pill {
        visible: view.settings.hint && view.plugin.shortcut !== ""

        Label {
          tone: "dim"
          text: MenuKeys.label(view.plugin.shortcut)
        }
      }

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

    // A click on a pill summons the cards, the held ones with them.
    MouseArea {
      anchors.fill: pills
      enabled: pills.visible
      onClicked: view.plugin.summon()
    }
  }
}
