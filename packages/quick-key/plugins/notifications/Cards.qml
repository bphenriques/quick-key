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
  // Whether any card shown has an app's icon: without one, no card keeps a column for it, so neither side sits empty.
  readonly property bool icons: plugin.shown.some(entry => iconOf(entry) !== "")

  // A picture, as the protocol orders them: image data, which Quickshell serves as image://qsimage, else an icon sent as a file (album art, a screenshot).
  function pictureOf(entry) {
    if (entry.image.startsWith("image://qsimage")) return entry.image;
    const file = plugin.fileOf(entry);
    return file ? "file://" + file.split("/").map(encodeURIComponent).join("/") : "";
  }

  // An icon sent by its name, from the theme, at a glyph's size; a rule's own first.
  function iconOf(entry) {
    if (entry.applied.icon) return Quickshell.iconPath(entry.applied.icon, true);
    const icon = plugin.iconOf(entry);
    return icon && !plugin.fileOf(entry) ? Quickshell.iconPath(icon, true) : "";
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
    onLoadedChanged: if (loaded) view.made = true
  }

  // The window, once made, hides rather than goes: making one costs more than a card.
  property bool made: false

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
    active: view.made

    OverlayWindow {
      id: window
      visible: fade.loaded
      // Hidden, a hover it never saw end would hold the cards for good.
      onVisibleChanged: if (!visible) view.plugin.hold(false)

      screen: view.screen
      // As tall as the cards, so blocking it from screen capture hides them and nothing beside them.
      anchors.top: view.top
      anchors.bottom: !view.top
      anchors.right: view.right
      anchors.left: !view.right
      // In the corner pills' corner (recording), past them as they stack, a gap more.
      readonly property real pills: view.right && view.top !== Config.atTop && CornerPills.order.length > 0 ? Config.theme.edgeMargin + CornerPills.height + Config.theme.spacing : 0
      margins.top: view.top ? Math.max(view.settings.margin, pills) : view.settings.margin
      margins.bottom: view.top ? view.settings.margin : Math.max(view.settings.margin, pills)
      // Larger by the room a slide needs on its corner's side, the margin smaller by as much.
      readonly property real room: Math.min(fade.distance, view.settings.margin)
      margins.right: view.settings.margin - (view.right ? room : 0)
      margins.left: view.settings.margin - (view.right ? 0 : room)
      // No wider than its screen within the margins, whatever width is set.
      implicitWidth: Math.min(view.settings.width, (view.screen?.width ?? view.settings.width) - 2 * view.settings.margin) + room
      implicitHeight: stack.implicitHeight
      WlrLayershell.namespace: "quick-key-notifications"
      WlrLayershell.keyboardFocus: view.plugin.summoned ? WlrKeyboardFocus.Exclusive : WlrKeyboardFocus.None
      // The cards and the ends, which at rest are only as wide as their pills: clicks beside them reach what is under.
      mask: Region {
        item: deck
        Region {
          item: lead.visible ? lead : null
        }
        Region {
          item: trail.visible ? trail : null
        }
      }

      // Each card blurred behind on its own, as the menu is, the gaps between them left clear.
      BackgroundEffect.blurRegion: Region {
        regions: Array.from({ length: blurs.count }, (_, i) => blurs.objectAt(i))
      }

      Instantiator {
        id: blurs
        model: view.settings.limit

        Region {
          required property int index
          readonly property var card: cards.count > index ? cards.itemAt(index) : null
          // Its card's place in the window, by the stack and the deck it sits in: given by item, it would follow the card alone, not what moves it (the pills' row above).
          x: card?.visible ? stack.x + deck.x + card.x : 0
          y: card?.visible ? stack.y + deck.y + card.y : 0
          width: card?.visible ? card.width : 0
          height: card?.visible ? card.height : 0
          radius: Config.theme.radius
        }
      }

      FocusScope {
        anchors.fill: parent
        focus: true
        Keys.onPressed: event => event.accepted = view.plugin.key(MenuKeys.name(event))

        Column {
          id: stack
          // Sliding, in from the side of its corner within the room left for it, moved itself so the cards' blur moves with them.
          x: view.right ? (1 - fade.value) * window.room : fade.value * window.room
          width: parent.width - window.room
          spacing: Config.theme.spacing
          opacity: fade.value

          // Over the whole stack, its gaps too, so moving between cards never lets go.
          HoverHandler {
            onHoveredChanged: view.plugin.hold(hovered)
          }

          Ends {
            id: lead
            visible: !view.top
          }

          Column {
            id: deck
            width: parent.width
            visible: view.cards.length > 0
            spacing: Config.theme.spacing

            Repeater {
              id: cards
              // As many as can show, past the cards hidden: a count that changed would make every card again.
              model: view.settings.limit

              Card {
                id: card
                required property int index
                readonly property var entry: view.cards[index] ?? null
                visible: entry !== null
                readonly property var hint: entry?.hints.value

                width: stack.width
                recolour: Config.theme.appIcons
                iconColumn: view.icons
                icon: entry ? view.iconOf(entry) : ""
                image: entry ? view.pictureOf(entry) : ""
                readonly property string app: entry ? view.plugin.appOf(entry) : ""
                title: entry?.summary || app || (entry?.appName ?? "")
                // Its count, its app where nothing else names it (its icon from the theme may), and when it came once it has waited.
                aside: !entry ? "" : view.plugin.asideOf(entry, title, icon !== "", view.plugin.ageOf(entry))
                body: entry?.body ?? ""
                tone: entry && view.plugin.critical(entry) ? "alert" : ""
                meter: typeof hint === "number" ? Math.max(0, Math.min(100, hint)) / 100 : -1
                meterText: meter >= 0 ? Math.round(meter * 100) + "%" : ""
                actions: view.plugin.actionsOf(entry)
                footer: entry !== null && entry === view.plugin.replying ? reply : null
                actionSide: view.settings.actionSide
                // Its place among all, while a digit reaches it.
                readonly property int place: view.plugin.showable.indexOf(entry)
                key: place >= 0 && place < 9 ? String(place + 1) : ""
                closeKey: "x"
                // Replying, the prompt has the keys: the others would type; after a closed reply, ESC alone.
                keysShown: view.plugin.summoned && (view.plugin.mode === "cards" || view.plugin.mode === "help")
                current: view.plugin.summoned && entry === view.plugin.picked
                onActivated: view.plugin.open(entry)
                onDismissed: view.plugin.dismiss(entry)
              }
            }
          }

          Ends {
            id: trail
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
      // The icon's column, else the gutter, so the text starts with the body's.
      slot: view.icons ? Config.theme.iconSize : Metrics.cell
      // One line, scrolling, in the actions' place: the card keeps its height.
      maxLines: 1
      placeholder: view.plugin.replying?.inlineReplyPlaceholder || Words.replyPrompt
      onBack: view.plugin.endReply()
      Component.onCompleted: set(view.plugin.replying?.draft ?? "")
      onTextChanged: view.plugin.keepDraft(view.plugin.replying, text)
      onKeyPressed: event => {
        const send = MenuKeys.sends(event);
        if (!send) return;
        event.accepted = true;
        view.plugin.sendReply(text, send === "background");
      }
    }
  }

  // The side away from the corner: summoned, the keys; else those over the limit, those held, and the key that summons.
  component Ends: Item {
    width: view.plugin.summoned ? parent.width : pills.implicitWidth
    x: view.right && !view.plugin.summoned ? parent.width - width : 0
    implicitHeight: view.plugin.summoned ? bar.implicitHeight : pills.implicitHeight

    // Summoned: the keys the state changes on the left, what it reports on the right; `?` lists every key in its place.
    Surface {
      id: bar
      visible: view.plugin.summoned
      width: parent.width
      color: Tone.surface(1)
      implicitHeight: (view.plugin.mode === "help" ? list.implicitHeight : barRow.implicitHeight) + Config.theme.padding / 2

      KeyList {
        id: list
        // One column: the stack is a card wide.
        columns: 1
        visible: view.plugin.mode === "help"
        anchors.verticalCenter: parent.verticalCenter
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.leftMargin: Config.theme.padding - Config.theme.itemPaddingX
        anchors.rightMargin: Config.theme.padding
        keys: view.plugin.keys
      }

      RowLayout {
        id: barRow
        visible: view.plugin.mode !== "help"
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
          keys: view.plugin.mode === "closed" ? [{ key: "Escape", what: view.plugin.words.letGo }]
            : view.plugin.mode === "reply" ? [{ key: "Return", what: view.plugin.words.send }, { key: "Ctrl+Shift+Return", what: view.plugin.words.sendLeave }].concat((view.plugin.replying?.draft ?? "") !== "" ? [{ key: "Escape", what: Words.clear }] : [])
            : [{ key: "Ctrl+p", what: view.plugin.paused ? view.plugin.words.resume : view.plugin.words.pause }, { key: "?", what: Words.help }]
        }

        Label {
          visible: text !== ""
          tone: view.plugin.mode === "closed" ? "warning" : "dim"
          text: view.plugin.mode === "closed" ? (view.plugin.copied ? view.plugin.words.replyCopied : view.plugin.words.cardClosed) : view.plugin.mode === "reply" ? "" : view.plugin.shown.length === 0 ? view.plugin.words.none : view.plugin.more > 0 ? "+" + view.plugin.more : ""
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
