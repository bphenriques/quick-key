pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui
import qs.builtins
import qs.widgets.menu.calendar

// The keyboard menu with live status: entries come from programs.quick-key.settings.menu.entries.
Scope {
  id: root

  readonly property MenuModel menu: MenuModel {}
  // While a held modifier lists keys in place of the body.
  readonly property bool hinting: menu.hints.length > 0

  // A key of the input's clicked in the legend, for the prompt, which lives in the panel's input.
  signal inputPicked(var key)

  // The modifier whose keys show when held: Ctrl the bar's, Super the compositor's.
  function modifier(event) {
    if (event.key === Qt.Key_Control) return "Ctrl";
    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) return "Super";
    return "";
  }

  Binding {
    target: Plugins
    property: "menuOpen"
    value: root.menu.open
  }

  Binding {
    target: Plugins
    property: "watching"
    value: root.menu.watching
  }

  IpcHandler {
    target: "menu"

    function toggle(): void {
      root.menu.toggle();
    }

    function toggleEntry(key: string): void {
      root.menu.toggleEntry(key);
    }
  }

  Timer {
    id: held
    property string modifier
    interval: 1000
    onTriggered: root.menu.held = modifier
  }

  Panel {
    shown: root.menu.open
    namespace: "menu"
    width: root.menu.width
    barShown: root.menu.barItems.length > 0
    onDismissed: root.menu.hide()
    // As Backspace does.
    onSecondaryClicked: if (root.menu.level) root.menu.back()
    onKeyPressed: event => {
      if (root.modifier(event) && !event.isAutoRepeat) {
        held.modifier = root.modifier(event);
        held.restart();
      }
      event.accepted = root.menu.handleKey(event);
    }
    onKeyReleased: event => {
      if (!root.modifier(event)) return;
      held.stop();
      root.menu.held = "";
    }

    bar: MenuHeader {
      menu: root.menu
    }

    inputShown: root.menu.input !== null
    inputFocused: root.menu.inputFocused
    // The conversation's last turn (Exchange, drawn by its state) over the line to send: Return sends it and keeps the focus for the next, Ctrl+Shift+Return sends it in the background.
    input: ColumnLayout {
      id: island
      spacing: Config.theme.spacing / 2

      // Lit while Tab has it; a click, or Return then, opens the plugin's panel on the whole conversation.
      ListItem {
        id: last
        // The tallest turn of the visit, which the island keeps so it grows and never shrinks within it.
        property real held: 0
        // A turn it cannot hold opens the plugin's panel by itself, once.
        readonly property bool expands: visible && exchange.overflows && root.menu.turn !== root.menu.expandedTurn
        visible: root.menu.turn !== null
        Layout.fillWidth: true
        // Outset by its padding, so the bubbles line up with the prompt.
        Layout.leftMargin: -Config.theme.itemPaddingX
        Layout.rightMargin: -Config.theme.itemPaddingX
        onVisibleChanged: if (!visible) held = 0
        onExpandsChanged: if (expands) settle.restart()
        verticalPadding: Config.theme.itemPaddingY / 2
        current: root.menu.answerFocused
        onActivated: root.menu.expand()

        // Decided once the turn is laid out, so a line cut only for a moment opens nothing, and outside the binding that noticed it.
        Timer {
          id: settle
          interval: 100
          onTriggered: if (last.expands) root.menu.overflowed()
        }

        // Held once laid out, so a height the text has only for a moment, before it has its width, is not kept.
        Timer {
          id: latch
          interval: 100
          onTriggered: last.held = Math.max(last.held, exchange.implicitHeight)
        }

        // The turn at the bottom of the height held, next to the prompt, as a chat grows.
        Item {
          Layout.fillWidth: true
          implicitHeight: Math.max(exchange.implicitHeight, last.held)

          Exchange {
            id: exchange
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            onImplicitHeightChanged: latch.restart()
            lines: 3
            maximumWidth: island.width * 0.85
            question: root.menu.turn?.question ?? ""
            context: root.menu.turn?.context ?? ""
            text: root.menu.turn?.text ?? ""
            phase: root.menu.turn?.phase ?? "answered"
            activity: root.menu.turn?.activity ?? ""
            options: root.menu.choices
            table: !!root.menu.turn?.table
            // Set aside, the options wait as text and the digits type again.
            picking: root.menu.turn?.phase === "choosing" && !root.menu.choicesAside && fits
          }
        }
      }

      Prompt {
        id: prompt
        Layout.fillWidth: true
        active: root.menu.inputFocused
        // A turn shows its own spinner; without one (a chat running in the plugin's panel), the prompt does.
        busy: root.menu.inputBusy && root.menu.turn === null
        key: "Tab"
        // What Return does next: ask, reply, or pick.
        placeholder: !root.menu.turn ? root.menu.input?.desc ?? "" : root.menu.turn.phase === "working" ? "Answering…" : exchange.picking ? "A digit picks, or reply…" : "Reply…"
        maxLines: 1
        onTapped: root.menu.inputFocused = true
        onUnfocused: root.menu.inputFocused = false
        // The level's own unsent text, as it opens or moves to another input.
        readonly property var owner: root.menu.input
        onOwnerChanged: set(root.menu.draftOf(owner))
        Component.onCompleted: set(root.menu.draftOf(owner))
        onTextChanged: root.menu.keepDraft(text)
        // Tab moves on to the turn, else to the body as Shift+Tab does; while the line is empty, a waiting choice takes the digits and Escape.
        onKeyPressed: event => {
          const send = MenuKeys.sends(event);
          const name = MenuKeys.name(event);
          // A choice waiting takes the digits whether or not they all show here, so they never type.
          const waiting = root.menu.turn?.phase === "choosing" && !root.menu.choicesAside && prompt.text === "";
          if (send) prompt.send(send === "background");
          else if (waiting && /^[1-9]$/.test(name)) {
            if (exchange.picking) root.menu.pick(Number(name) - 1);
          } else if (waiting && name === "Escape") root.menu.choicesAside = true;
          else if (name === "Tab" && last.visible) {
            root.menu.inputFocused = false;
            root.menu.answerFocused = true;
          } else if (name === "Tab" || name === "Backtab") root.menu.inputFocused = false;
          else return;
          event.accepted = true;
        }

        function send(background) {
          // Cleared first: sending may close the menu, and the prompt with it.
          const text = prompt.text;
          prompt.clear();
          if (!root.menu.submit(text, background)) prompt.set(text);
        }

        Connections {
          target: root

          function onInputPicked(key) {
            if (key === "Escape") prompt.stepBack();
            else prompt.send(true);
          }
        }

        // A failed turn gives back what was sent, so Return retries it.
        Connections {
          target: root.menu.inputPlugin

          function onTurnChanged() {
            if (root.menu.inputPlugin.turn?.phase === "failed" && prompt.text === "") prompt.set(root.menu.lastSent);
          }
        }
      }
    }

    body: ColumnLayout {
      id: body
      // Its height before a held modifier listed its keys, which it keeps while they show, so the panel holds still.
      property real restHeight: 0
      onImplicitHeightChanged: if (!root.hinting) restHeight = implicitHeight
      spacing: Config.theme.padding

      // The keys a held modifier reaches, in the body's own columns; each still runs on a click.
      GridLayout {
        id: hints
        Layout.fillWidth: true
        visible: root.hinting
        flow: GridLayout.LeftToRight
        columns: Config.menu.columns
        columnSpacing: Config.theme.padding
        rowSpacing: Config.theme.listSpacing

        Repeater {
          model: root.menu.hints.length

          MenuRow {
            required property int index
            item: root.menu.hints[index] ?? ({})
            menu: root.menu
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            chars: root.menu.keyChars(root.menu.hints)
          }
        }
      }

      // Fewer keys than rows leave the rest of the body empty rather than shrink it.
      Item {
        visible: root.hinting && body.restHeight > hints.implicitHeight + body.spacing
        Layout.preferredHeight: body.restHeight - hints.implicitHeight - body.spacing
      }

      // A level's legend shares its line with its actions, the keys on the left and the actions on the right.
      RowLayout {
        Layout.fillWidth: true
        visible: !root.hinting && (root.menu.legend.length > 0 || root.menu.actions.length > 0)
        spacing: Config.theme.padding

        KeyLegend {
          visible: root.menu.legend.length > 0
          keys: root.menu.legend
          onPicked: key => root.menu.inputFocused ? root.inputPicked(key) : root.menu.calendar.handleKey(key)
        }

        Item {
          visible: root.menu.legend.length > 0
          Layout.fillWidth: true
        }

        // Declared columns, entries flowing across; hidden when empty, since an empty GridLayout keeps its last height.
        GridLayout {
          id: actionsGrid
          Layout.fillWidth: root.menu.legend.length === 0
          visible: root.menu.actions.length > 0
          flow: GridLayout.LeftToRight
          columns: Config.menu.columns
          columnSpacing: Config.theme.padding
          rowSpacing: Config.theme.listSpacing

          Repeater {
            model: root.menu.actions.length

            // At the top, values line up in equal columns; in a level, the last column hugs its rows against the right edge.
            MenuRow {
              required property int index
              item: root.menu.actions[index] ?? ({})
              hugs: root.menu.level !== null && index % actionsGrid.columns === actionsGrid.columns - 1
              menu: root.menu
              Layout.fillWidth: !hugs
              Layout.preferredWidth: hugs ? -1 : 1
              chars: root.menu.columnChars(index, actionsGrid.columns)
            }
          }
        }
      }

      Label {
        Layout.fillWidth: true
        Layout.leftMargin: Config.theme.itemPaddingX
        Layout.rightMargin: Config.theme.itemPaddingX
        visible: !root.hinting && root.menu.error !== ""
        // Alert, not warning: the warning hue sits too close to calendar colours to read as a fault.
        tone: "alert"
        wrapMode: Text.Wrap
        text: root.menu.error
      }

      Divider {
        Layout.fillWidth: true
        visible: !root.hinting && root.menu.actions.length > 0 && (root.menu.rows.length > 0 || root.menu.emptyText !== "" || !!root.menu.level?.entry?.view)
      }

      // An empty list says why, in its place.
      Label {
        visible: !root.hinting && root.menu.emptyText !== ""
        Layout.leftMargin: Config.theme.itemPaddingX
        tone: "dim"
        text: root.menu.emptyText
      }

      // What a level lists, apart from its actions and across the full width.
      ColumnLayout {
        Layout.fillWidth: true
        visible: !root.hinting && root.menu.rows.length > 0
        spacing: Config.theme.listSpacing

        Repeater {
          model: root.menu.rows.length

          MenuRow {
            required property int index
            item: root.menu.rows[index] ?? ({})
            menu: root.menu
            Layout.fillWidth: true
            chars: root.menu.keyChars(root.menu.rows)
          }
        }
      }

      // The month, and the events from its selected day beside it as tall as the month, 2 to 3; built only while shown, as it is most of what an opening builds.
      Loader {
        Layout.fillWidth: true
        active: root.menu.inCalendar
        visible: !root.hinting && active

        sourceComponent: RowLayout {
          spacing: Config.theme.padding

          CalendarMonth {
            Layout.fillWidth: true
            Layout.preferredWidth: 2
            Layout.alignment: Qt.AlignTop
            title: root.menu.calendar.title
            selected: root.menu.calendar.selected
            onStepped: months => root.menu.calendar.moveSelected(0, months, 0)
            onPicked: day => root.menu.calendar.select(day)
          }

          Divider {
            Layout.fillHeight: true
            visible: events.visible
          }

          CalendarEvents {
            id: events
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.preferredWidth: 3
            Layout.preferredHeight: 0
            visible: Calendar.enabled
            selected: root.menu.calendar.selected
            focused: root.menu.calendar.focused
            onPicked: row => root.menu.calendar.focus(row)
          }
        }
      }
    }
  }
}
