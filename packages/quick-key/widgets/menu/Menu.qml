pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui
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

  Component {
    id: statuses

    HeaderSlot {
      implicitWidth: Layout.preferredWidth
      menu: root.menu
      alignment: Qt.AlignRight
      items: root.menu.barOf(root.menu.topBar.right)
    }
  }

  Binding {
    target: Panels
    property: "statuses"
    value: statuses
  }

  IpcHandler {
    target: "menu"

    function toggle(): void {
      root.menu.toggle();
    }

    function toggleEntry(key: string): void {
      root.menu.toggleEntry(key);
    }

    // A key path from the top level, as typing it would run it (`a 2`).
    function press(path: string): bool {
      return root.menu.press(path);
    }

    // Every key path, as Markdown.
    function keys(): string {
      return root.menu.keyMap();
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
    barShown: root.menu.barShown
    inputOver: true
    onDismissed: root.menu.hide()
    // As Escape does, but never closing the top level.
    onSecondaryClicked: if (root.menu.level) root.menu.stepBack()
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
      // Filtering, the filter's keys; else as typed.
      onPicked: key => root.menu.filtering ? (key === "Escape" ? root.menu.island.picked(key) : root.menu.filterKey(key)) : root.menu.handleName(key)
    }

    // Filtering, the filter takes the island, the level's input waiting under it.
    inputShown: root.menu.island.input !== null || root.menu.filtering
    inputFocused: root.menu.inputFocused || root.menu.filtering
    input: Island {
      menu: root.menu
    }

    body: ColumnLayout {
      id: body
      // Its height before a held modifier listed its keys, which it keeps while they show, so the panel holds still.
      property real restHeight: 0
      onImplicitHeightChanged: if (!root.hinting) restHeight = implicitHeight
      spacing: Config.theme.padding

      // Fewer keys than rows leave the top of the body empty rather than shrink it, the keys next to the bar.
      Item {
        visible: root.hinting && body.restHeight > hints.implicitHeight + body.spacing
        Layout.preferredHeight: body.restHeight - hints.implicitHeight - body.spacing
      }

      // The keys a held modifier reaches, in the body's own columns; each still runs on a click.
      GridLayout {
        id: hints
        Layout.fillWidth: true
        visible: root.hinting
        flow: GridLayout.LeftToRight
        columns: root.menu.columns
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

      // An empty list says why, in its place.
      Label {
        visible: !root.hinting && !root.menu.filtering && root.menu.emptyText !== ""
        Layout.leftMargin: Config.theme.itemPaddingX
        tone: "dim"
        text: root.menu.emptyText
      }

      // What a level lists, apart from its actions and across the full width; filtering, as tall as its rows were, so nothing moves as the filter narrows.
      ColumnLayout {
        Layout.fillWidth: true
        Layout.preferredHeight: root.menu.filtering ? root.menu.filterSlots * filledRow.implicitHeight + (root.menu.filterSlots - 1) * spacing : -1
        visible: !root.hinting && (root.menu.rows.length > 0 || root.menu.filtering)
        spacing: Config.theme.listSpacing

        // A filled row's height, for the rows held while filtering.
        MenuRow {
          id: filledRow
          visible: false
          menu: root.menu
          item: ({ key: "1", desc: "x", icon: Glyphs.search })
        }

        Label {
          visible: root.menu.filtering && root.menu.emptyText !== ""
          Layout.leftMargin: Config.theme.itemPaddingX
          Layout.topMargin: Config.theme.itemPaddingY
          tone: "dim"
          text: root.menu.emptyText
        }

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

        Item {
          visible: root.menu.filtering
          Layout.fillHeight: true
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

      // A menu's entries, in declared columns flowing across; hidden when empty, since an empty GridLayout keeps its last height.
      GridLayout {
        id: actionsGrid
        Layout.fillWidth: true
        visible: !root.hinting && root.menu.bodyActions.length > 0
        flow: GridLayout.LeftToRight
        columns: root.menu.columns
        columnSpacing: Config.theme.padding
        rowSpacing: Config.theme.listSpacing

        Repeater {
          model: root.menu.bodyActions.length

          // At the top, values line up in equal columns; in a level, the last column hugs its rows against the right edge.
          MenuRow {
            required property int index
            item: root.menu.bodyActions[index] ?? ({})
            hugs: root.menu.level !== null && index % actionsGrid.columns === actionsGrid.columns - 1
            menu: root.menu
            Layout.fillWidth: !hugs
            Layout.preferredWidth: hugs ? -1 : 1
            chars: root.menu.columnChars(index, actionsGrid.columns)
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
    }
  }
}
