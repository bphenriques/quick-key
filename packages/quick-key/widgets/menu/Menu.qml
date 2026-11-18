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

    // One line: Return sends it and keeps the focus for the next, Escape clears it, then gives the keys back.
    input: Prompt {
      id: prompt
      active: root.menu.inputFocused
      key: root.menu.input?.key ?? ""
      placeholder: root.menu.input?.desc ?? ""
      maxLines: 1
      onTapped: root.menu.inputFocused = true
      onKeyPressed: event => {
        const name = MenuKeys.name(event);
        if (name === "Return") {
          root.menu.submit(prompt.text);
          prompt.clear();
        } else if (name === "Escape") {
          if (prompt.text) prompt.clear();
          else root.menu.inputFocused = false;
        } else {
          return;
        }
        event.accepted = true;
      }
    }

    body: ColumnLayout {
      spacing: Config.theme.padding

      // The keys a held modifier reaches, in the body's own columns; each still runs on a click.
      GridLayout {
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

      // A level's legend shares its line with its actions, the keys on the left and the actions on the right.
      RowLayout {
        Layout.fillWidth: true
        visible: !root.hinting && (root.menu.legend.length > 0 || root.menu.actions.length > 0)
        spacing: Config.theme.padding

        KeyLegend {
          visible: root.menu.legend.length > 0
          keys: root.menu.legend
          onPicked: key => root.menu.calendar.handleKey(key)
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
