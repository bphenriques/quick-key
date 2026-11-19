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
    // What the input's plugin said, over the line to send: Return sends it and keeps the focus for the next, Ctrl+Shift+Return sends it in the background.
    input: ColumnLayout {
      spacing: Config.theme.spacing / 2

      Answer {
        id: answer
        visible: root.menu.reply !== null
        question: root.menu.reply?.question ?? root.menu.lastSent
        text: root.menu.reply?.text ?? ""
        tone: root.menu.reply?.tone ?? ""
        table: !!root.menu.reply?.table
        options: root.menu.choices
        // Running, the options wait as text: nothing to pick until the answer is in.
        aside: root.menu.choicesAside || root.menu.inputBusy
        glyph: root.menu.inputPlugin?.glyph ?? ""
        slot: prompt.slot
        current: root.menu.answerFocused
        onActivated: root.menu.expand()
      }

      Prompt {
        id: prompt
        Layout.fillWidth: true
        active: root.menu.inputFocused
        busy: root.menu.inputBusy
        key: "Tab"
        placeholder: root.menu.input?.desc ?? ""
        maxLines: 1
        onTapped: root.menu.inputFocused = true
        onUnfocused: root.menu.inputFocused = false
        // The level's own unsent text, as it opens or moves to another input.
        readonly property var owner: root.menu.input
        onOwnerChanged: set(root.menu.draftOf(owner))
        Component.onCompleted: set(root.menu.draftOf(owner))
        onTextChanged: root.menu.keepDraft(text)
        // Tab moves on to the answer, else to the body as Shift+Tab does; while the line is empty, a waiting choice takes the digits and Escape.
        onKeyPressed: event => {
          const send = MenuKeys.sends(event);
          const name = MenuKeys.name(event);
          // A choice waiting takes the digits whether or not they all show here, so they never type.
          const waiting = answer.visible && answer.options.length > 0 && !answer.aside && prompt.text === "";
          if (send) prompt.send(send === "background");
          else if (waiting && /^[1-9]$/.test(name)) {
            if (answer.picking) root.menu.pick(Number(name) - 1);
          } else if (waiting && name === "Escape") root.menu.choicesAside = true;
          else if (name === "Tab" && answer.visible) {
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

        // A failed answer gives back what was sent, so Return retries it.
        Connections {
          target: root.menu.inputPlugin

          function onReplyChanged() {
            if (root.menu.inputPlugin.reply?.tone === "alert" && prompt.text === "") prompt.set(root.menu.lastSent);
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
