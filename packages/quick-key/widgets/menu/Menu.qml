pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import Quickshell.Wayland
import qs
import qs.services
import qs.ui
import qs.builtins
import qs.widgets.menu.calendar

// The keyboard menu with live status: entries come from programs.quick-key.settings.menu.entries.
Scope {
  id: root

  readonly property MenuModel menu: MenuModel {}

  Binding {
    target: Plugins
    property: "menuOpen"
    value: root.menu.open
  }

  Binding {
    target: Audio
    property: "metering"
    value: !!Statuses.builtin[root.menu.level?.status]?.sampled
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

  LazyLoader {
    id: dismiss
    active: root.menu.open

    Variants {
      model: Quickshell.screens

      DismissArea {
        required property var modelData
        screen: modelData
        onDismissed: root.menu.hide()
      }
    }
  }

  // Created after the dismiss areas, so it stacks above them on the same layer.
  LazyLoader {
    active: root.menu.open && dismiss.item !== null

    OverlayWindow {
      // The whole screen, so levels of different sizes never resize the window: a resize shows the old size for a frame.
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      WlrLayershell.namespace: "menu"
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      // Clicks beside the card reach the dismiss area below.
      mask: Region {
        item: card
      }
      BackgroundEffect.blurRegion: Region {
        item: card
        radius: Config.theme.radius
      }

      Shadow {
        anchors.fill: card
        radius: card.radius
      }

      Surface {
        id: card
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.bottom: parent.bottom
        anchors.bottomMargin: Config.theme.edgeMargin
        width: root.menu.width
        height: content.implicitHeight + 2 * Config.theme.padding

        function isSuper(event) {
          return event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta;
        }

        focus: true
        Keys.onPressed: event => {
          if (isSuper(event) && !event.isAutoRepeat) superHeld.start();
          event.accepted = root.menu.handleKey(event);
        }
        Keys.onReleased: event => {
          if (!isSuper(event)) return;
          superHeld.stop();
          root.menu.shortcutsShown = false;
        }

        Timer {
          id: superHeld
          interval: 1000
          onTriggered: root.menu.shortcutsShown = true
        }

        ColumnLayout {
          id: content
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Config.theme.padding
          spacing: Config.theme.padding

          MenuHeader {
            Layout.fillWidth: true
            menu: root.menu
          }

          // A level's legend shares its line with its actions, the keys on the left and the actions on the right.
          RowLayout {
            Layout.fillWidth: true
            visible: root.menu.legend.length > 0 || root.menu.actions.length > 0
            spacing: Config.theme.padding

            KeyLegend {
              visible: root.menu.legend.length > 0
              keys: root.menu.legend
              onPicked: key => root.menu.calendar.handleKey(key)
            }

            Item {
              Layout.fillWidth: root.menu.legend.length > 0
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
                model: root.menu.actions

                MenuRow {
                  required property int index
                  menu: root.menu
                  Layout.fillWidth: true
                  Layout.preferredWidth: 1
                  chars: root.menu.columnChars(index, actionsGrid.columns)
                }
              }
            }
          }

          Label {
            Layout.fillWidth: true
            Layout.leftMargin: Config.theme.itemPaddingX
            Layout.rightMargin: Config.theme.itemPaddingX
            visible: !!root.menu.level?.entry?.view && Calendar.error !== "" && !Calendar.syncing
            // Alert, not warning: the warning hue sits too close to calendar colours to read as a fault.
            tone: "alert"
            wrapMode: Text.Wrap
            text: Calendar.error
          }

          Divider {
            Layout.fillWidth: true
            visible: root.menu.actions.length > 0 && (root.menu.rows.length > 0 || root.menu.emptyText !== "" || !!root.menu.level?.entry?.view)
          }

          // An empty list says why, in its place.
          Label {
            visible: root.menu.emptyText !== ""
            Layout.leftMargin: Config.theme.itemPaddingX
            tone: "dim"
            text: root.menu.emptyText
          }

          // What a level lists, apart from its actions and across the full width.
          ColumnLayout {
            Layout.fillWidth: true
            visible: root.menu.rows.length > 0
            spacing: Config.theme.listSpacing

            Repeater {
              model: root.menu.rows

              MenuRow {
                menu: root.menu
                Layout.fillWidth: true
                chars: root.menu.keyChars(root.menu.rows)
              }
            }
          }

          // The month, and the events from its selected day beside it as tall as the month, 2 to 3.
          RowLayout {
            Layout.fillWidth: true
            visible: root.menu.inCalendar
            spacing: Config.theme.padding

            CalendarMonth {
              Layout.fillWidth: true
              Layout.preferredWidth: 2
              Layout.alignment: Qt.AlignTop
              selected: root.menu.calendar.selected
              onStepped: months => root.menu.calendar.moveSelected(0, months, 0)
              onPicked: day => root.menu.calendar.select(day)
            }

            Divider {
              Layout.fillHeight: true
              implicitWidth: Config.theme.borderWidth / 2
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
}
