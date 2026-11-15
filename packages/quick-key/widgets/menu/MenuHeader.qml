import QtQuick
import QtQuick.Layouts
import qs
import qs.builtins
import qs.ui

// As in waybar, nothing grows the menu; the top level shows Config.menu.header, a level its title and state.
RowLayout {
  id: header

  required property MenuModel menu
  // Both sides as wide when there is a centre to keep centred.
  readonly property bool centred: centreSlot.visible
  readonly property real sideMinimum: Math.max(leftSlot.contentMinimum, rightSlot.contentMinimum)

  // Never widens the menu: a header whose icons cannot fit overflows instead (rule 4: make the menu wider).
  Layout.minimumWidth: 0
  spacing: Config.theme.spacing

  HeaderSlot {
    id: leftSlot
    menu: header.menu
    centred: header.centred
    sideMinimum: header.centred ? header.sideMinimum : contentMinimum
    items: header.menu.level ? [] : Config.menu.header.left

    // Inside a level the title goes back up, like Backspace.
    ListItem {
      visible: header.menu.level !== null
      onActivated: header.menu.back()

      Label {
        font.bold: true
        text: header.menu.title
      }
    }
  }

  HeaderSlot {
    id: centreSlot
    menu: header.menu
    alignment: Qt.AlignHCenter
    items: header.menu.level ? [] : Config.menu.header.center
  }

  HeaderSlot {
    id: rightSlot
    menu: header.menu
    centred: header.centred
    sideMinimum: header.centred ? header.sideMinimum : contentMinimum
    alignment: Qt.AlignRight
    items: header.menu.level ? [] : Config.menu.header.right

    // A level that lists its items (tray apps, devices, networks) shows only its state, not the items again.
    MenuStatus {
      visible: header.menu.level !== null
      Layout.rightMargin: Config.theme.itemPaddingX
      quiet: true
      compact: !!header.menu.level?.entry?.list
      status: Statuses.builtin[header.menu.level?.status]?.inLevel === false ? "" : header.menu.level?.status ?? ""
    }
  }
}
