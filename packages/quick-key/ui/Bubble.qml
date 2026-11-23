import QtQuick
import QtQuick.Layouts
import qs

// A message in a conversation: yours (`mine`) a bubble on the right, the other plain on the left; as wide as its content, up to `maximumWidth`.
Rectangle {
  id: root

  default property alias content: column.data
  property bool mine: false
  // One that did not go through, faded whole as a row that cannot run is.
  property bool faded: false
  property real maximumWidth: Infinity
  // As wide as it may be, whatever it holds: text cut at a line count reports the width it was cut to, and sized by it the bubble would never settle.
  property bool full: false

  readonly property real paddingX: mine ? Config.theme.itemPaddingX : 0

  Layout.alignment: mine ? Qt.AlignRight : Qt.AlignLeft
  Layout.preferredWidth: full ? maximumWidth : Math.min(column.implicitWidth + 2 * paddingX, maximumWidth)
  implicitHeight: column.implicitHeight + 2 * Config.theme.itemPaddingY
  radius: Config.theme.itemRadius * 2
  color: mine ? Config.colors.bubble : "transparent"
  opacity: faded ? Config.theme.disabledOpacity : 1

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.leftMargin: root.paddingX
    anchors.rightMargin: root.paddingX
    anchors.topMargin: Config.theme.itemPaddingY
    anchors.bottomMargin: Config.theme.itemPaddingY
    spacing: Config.theme.spacing / 2
  }
}
