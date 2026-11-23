pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell

// A third of a bar; sides get at least their items' width so the clock is never cut, the centre shortens its text.
Item {
  id: slot

  required property MenuModel menu
  property var items: []
  property int alignment: Qt.AlignLeft
  readonly property bool centre: alignment === Qt.AlignHCenter
  // The least its items need, summed from them: asking the row while the bar tears down its old items reads freed memory (a crash moving between levels).
  readonly property real contentMinimum: Array.from(row.children).reduce((sum, item) => sum + (item.visible && item.implicitWidth > 0 ? item.Layout.minimumWidth : 0), 0)
  readonly property real wanted: row.implicitWidth
  // What it draws, for an island behind it.
  readonly property Item content: row
  // Set on the sides: at least what their items need, or what either side needs when there is a centre to keep centred.
  property real sideMinimum: 0
  property bool centred: false

  visible: !centre || slot.items.length > 0
  Layout.fillWidth: true
  Layout.minimumWidth: centre ? contentMinimum : sideMinimum
  // Sides start from what their items want, or both from the same width when keeping a centre centred.
  Layout.preferredWidth: centre || !centred ? row.implicitWidth : sideMinimum
  Layout.maximumWidth: centre ? row.implicitWidth : Number.POSITIVE_INFINITY
  implicitHeight: row.implicitHeight

  RowLayout {
    id: row
    anchors.verticalCenter: parent.verticalCenter
    // Never wider than its share: its items' text gives way instead (see StatusLine).
    width: Math.min(implicitWidth, slot.width)
    x: slot.alignment === Qt.AlignRight ? slot.width - width : slot.alignment === Qt.AlignHCenter ? (slot.width - width) / 2 : 0
    // No spacing: each item's own padding already spaces them.
    spacing: 0

    Repeater {
      // By what each item is, so a tray icon's hover and tip follow it as others come and go.
      model: ScriptModel {
        values: slot.items
        objectProp: "uid"
      }

      HeaderItem {
        required property var modelData
        item: modelData
        menu: slot.menu
      }
    }
  }
}
