pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.ui

// A level's bar: a content level's actions and legend, then its slots like waybar's modules-left, -center and -right; as in waybar, nothing grows the menu.
RowLayout {
  id: header

  required property MenuModel menu
  // The width it is given, as Panel clamps the card: deciding from its laid-out width, which follows what it decides, loops.
  readonly property real room: Math.min(menu.width, (QsWindow.window?.width ?? 0) - 2 * (QsWindow.window?.edgeMargin ?? 0)) - 2 * Config.theme.padding
  // Both sides as wide when there is a centre to keep centred and room for both at that width; crowded, each side keeps what it needs, so the shortage falls on the text that can give most.
  readonly property bool centred: centreSlot.visible && 2 * Math.max(leftSlot.wanted, rightSlot.wanted) + centreSlot.wanted + 2 * spacing <= room
  readonly property real sideMinimum: Math.max(leftSlot.contentMinimum, rightSlot.contentMinimum)
  // What the slots and the legend leave the actions: with less than every label needs, all show their glyphs alone.
  readonly property real slotsWidth: [leftSlot, centreSlot, rightSlot].reduce((sum, slot) => sum + (slot.visible ? slot.wanted + spacing : 0), 0)
  readonly property real actionsRoom: room - slotsWidth - (legend.visible ? legend.implicitWidth + actions.spacing : 0)
  readonly property real labelledWidth: Array.from(labelled.children).reduce((sum, row) => sum + row.implicitWidth, Math.max(0, menu.barActions.length - 1) * actions.spacing)
  readonly property bool compact: labelledWidth > actionsRoom
  // What the bar needs at least, every text shortened, a spacing between each two items: past its width it overflows, which only a wider menu or fewer items mends, so the log says so.
  readonly property real needed: [leftSlot, centreSlot, rightSlot].reduce((sum, slot) => sum + (slot.visible ? slot.Layout.minimumWidth + spacing : 0), actions.visible ? 0 : -spacing)
  readonly property bool overflows: width > 0 && needed > width + 1
  onOverflowsChanged: if (overflows) console.warn("menu: the bar needs " + Math.ceil(needed) + " px, more than its " + Math.floor(width)
    + ": widen menu.width or the level's width, or list fewer items")

  // What each island holds with `menu.islands`: the actions, then each slot's items, which Panel draws apart.
  readonly property var islands: [actions, leftSlot.content, centreSlot.content, rightSlot.content]

  signal picked(var key)

  // Never widens the menu: a bar whose icons cannot fit overflows instead (rule 4: make the menu wider).
  Layout.minimumWidth: 0
  // As islands, wider apart by the padding each island adds on either side.
  spacing: Config.theme.spacing + (Config.menu.islands ? 2 * Config.theme.padding : 0)

  // As their rows draw them, so an action keeps its icon, state and value on the bar; filtering, the filter's keys alone.
  RowLayout {
    id: actions
    visible: header.menu.barActions.length > 0 || header.menu.legend.length > 0
    // Shrinks, never grows: past their glyphs alone, its rows' text gives way, as the slots' does.
    Layout.fillWidth: true
    Layout.maximumWidth: implicitWidth
    spacing: Config.theme.padding

    Repeater {
      model: header.menu.barActions.length

      MenuRow {
        required property int index
        item: header.menu.barActions[index] ?? ({})
        menu: header.menu
        hugs: true
        compact: header.compact
        Layout.fillWidth: true
        Layout.maximumWidth: implicitWidth
        chars: MenuKeys.label(item.key ?? "", item.paired ?? false).length
      }
    }

    KeyLegend {
      id: legend
      visible: header.menu.legend.length > 0
      keys: header.menu.legend
      onPicked: key => header.picked(key)
    }
  }

  // The actions with every label, never drawn, so whether they fit never depends on how they are drawn.
  Item {
    id: labelled
    visible: false

    Repeater {
      model: header.menu.barActions.length

      MenuRow {
        required property int index
        item: header.menu.barActions[index] ?? ({})
        menu: header.menu
        hugs: true
        chars: MenuKeys.label(item.key ?? "", item.paired ?? false).length
      }
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
