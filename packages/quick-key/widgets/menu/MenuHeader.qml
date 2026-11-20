pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.ui

// A level's bar: a content level's actions and legend, then its slots like waybar's modules-left, -center and -right; as in waybar, nothing grows the menu.
RowLayout {
  id: header

  required property MenuModel menu
  // Both sides as wide when there is a centre to keep centred.
  readonly property bool centred: centreSlot.visible
  readonly property real sideMinimum: Math.max(leftSlot.contentMinimum, rightSlot.contentMinimum)

  // A key of the legend clicked.
  signal picked(var key)

  // Never widens the menu: a bar whose icons cannot fit overflows instead (rule 4: make the menu wider).
  Layout.minimumWidth: 0
  spacing: Config.theme.spacing

  // As their rows draw them, so an action keeps its icon, state and value on the bar; filtering, the filter's keys alone.
  RowLayout {
    visible: header.menu.barActions.length > 0 || header.menu.legend.length > 0
    // Shrinks, never grows: its rows' text gives way, as the slots' does.
    Layout.fillWidth: true
    Layout.maximumWidth: implicitWidth
    // No spacing: each item's own padding already spaces them.
    spacing: 0

    Repeater {
      model: header.menu.barActions.length

      MenuRow {
        required property int index
        item: header.menu.barActions[index] ?? ({})
        menu: header.menu
        hugs: true
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        chars: MenuKeys.label(item.key ?? "", item.paired ?? false).length
      }
    }

    KeyLegend {
      visible: header.menu.legend.length > 0
      keys: header.menu.legend
      onPicked: key => header.picked(key)
    }
  }

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
