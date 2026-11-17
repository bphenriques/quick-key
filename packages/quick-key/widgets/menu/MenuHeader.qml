import QtQuick
import QtQuick.Layouts
import qs

// A level's bar, its slots like waybar's modules-left, -center and -right; as in waybar, nothing grows the menu.
RowLayout {
  id: header

  required property MenuModel menu
  // Both sides as wide when there is a centre to keep centred.
  readonly property bool centred: centreSlot.visible
  readonly property real sideMinimum: Math.max(leftSlot.contentMinimum, rightSlot.contentMinimum)

  // Never widens the menu: a bar whose icons cannot fit overflows instead (rule 4: make the menu wider).
  Layout.minimumWidth: 0
  spacing: Config.theme.spacing

  HeaderSlot {
    id: leftSlot
    menu: header.menu
    centred: header.centred
    sideMinimum: header.centred ? header.sideMinimum : contentMinimum
    items: header.menu.barSlots.left
  }

  HeaderSlot {
    id: centreSlot
    menu: header.menu
    alignment: Qt.AlignHCenter
    items: header.menu.barSlots.center
  }

  HeaderSlot {
    id: rightSlot
    menu: header.menu
    centred: header.centred
    sideMinimum: header.centred ? header.sideMinimum : contentMinimum
    alignment: Qt.AlignRight
    items: header.menu.barSlots.right
  }
}
