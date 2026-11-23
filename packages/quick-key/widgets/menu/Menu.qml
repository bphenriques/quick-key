pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.ui

Scope {
  id: root

  readonly property MenuModel menu: MenuModel {}
  readonly property bool hinting: menu.hints.length > 0

  function modifier(event) {
    if (event.key === Qt.Key_Control) return "Ctrl";
    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) return "Super";
    return "";
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

    function press(path: string): bool {
      return root.menu.press(path);
    }

    function keys(): string {
      return root.menu.keyMap();
    }
  }

  Timer {
    id: held
    property string modifier
    interval: 1000
    onTriggered: root.menu.hold(modifier)
  }

  Panel {
    shown: root.menu.open
    namespace: "menu"
    width: root.menu.width
    barShown: root.menu.barShown
    inputOver: Config.menu.inputSide === "body"
    islands: Config.menu.islands
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
      root.menu.hold("");
    }

    bar: MenuHeader {
      menu: root.menu
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

      // Fewer keys than rows leave the body's far side empty rather than shrink it, the keys next to the bar: above them, or below at the top edge.
      Item {
        visible: !Config.atTop && root.hinting && body.restHeight > hints.implicitHeight + body.spacing
        Layout.preferredHeight: body.restHeight - hints.implicitHeight - body.spacing
      }

      // The keys a held modifier reaches, in the body's own columns; each still runs on a click.
      GridLayout {
        id: hints
        Layout.fillWidth: true
        visible: root.hinting
        flow: GridLayout.LeftToRight
        columns: root.menu.columns
        columnSpacing: Math.max(Config.theme.padding, Metrics.cell)
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

      // The same room below the keys at the top edge, as the bar is above them.
      Item {
        visible: Config.atTop && root.hinting && body.restHeight > hints.implicitHeight + body.spacing
        Layout.preferredHeight: body.restHeight - hints.implicitHeight - body.spacing
      }

      Label {
        visible: !root.hinting && !root.menu.filtering && root.menu.emptyText !== ""
        Layout.leftMargin: Config.theme.itemPaddingX
        tone: "dim"
        text: root.menu.emptyText
      }

      // Filtering, as tall as its rows were, so nothing moves as the filter narrows.
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
            // As wide as the first column of actions too, so a list's labels start with theirs.
            chars: Math.max(root.menu.keyChars(root.menu.rows), root.menu.bodyActions.length ? root.menu.columnChars(0, actionsGrid.columns) : 1)
          }
        }

        Item {
          visible: root.menu.filtering
          Layout.fillHeight: true
        }
      }

      // A level's view (Views) with its model, built only while shown, as it is most of what an opening builds.
      Loader {
        readonly property var view: root.menu.view
        Layout.fillWidth: true
        visible: !root.hinting && item !== null
        onViewChanged: setSource(view ? view.source : "", { model: root.menu.viewModel })
      }

      // Hidden when empty, since an empty GridLayout keeps its last height.
      GridLayout {
        id: actionsGrid
        Layout.fillWidth: true
        visible: !root.hinting && root.menu.bodyActions.length > 0
        flow: GridLayout.LeftToRight
        columns: root.menu.columns
        columnSpacing: Math.max(Config.theme.padding, Metrics.cell)
        rowSpacing: Config.theme.listSpacing

        Repeater {
          model: root.menu.bodyActions.length

          // At the top, values line up in equal columns; in a level, the last column hugs its rows against the right edge.
          MenuRow {
            required property int index
            item: root.menu.bodyActions[index] ?? ({})
            hugs: root.menu.level !== null && index % actionsGrid.columns === actionsGrid.columns - 1
            menu: root.menu
            // Hugging, it fills no further than itself; not filling at all would fix it at its full width, past the card.
            Layout.fillWidth: true
            Layout.preferredWidth: hugs ? -1 : 1
            Layout.maximumWidth: hugs ? Math.ceil(implicitWidth) : Number.POSITIVE_INFINITY
            chars: index % actionsGrid.columns === 0 && root.menu.rows.length ? Math.max(root.menu.columnChars(index, actionsGrid.columns), root.menu.keyChars(root.menu.rows)) : root.menu.columnChars(index, actionsGrid.columns)
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
