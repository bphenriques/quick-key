import QtQuick
import QtQuick.Layouts
import qs

// A message in a conversation: yours (`mine`) on the right in the primary wash, the other's on the left; `tone` washes one that failed (alert). As wide as its content, up to `maximumWidth`.
Rectangle {
  id: root

  default property alias content: column.data
  property bool mine: false
  property string tone: ""
  property real maximumWidth: Infinity

  Layout.alignment: mine ? Qt.AlignRight : Qt.AlignLeft
  Layout.preferredWidth: Math.min(column.implicitWidth + 2 * Config.theme.itemPaddingX, maximumWidth)
  implicitHeight: column.implicitHeight + 2 * Config.theme.itemPaddingY
  radius: Config.theme.itemRadius * 2
  color: Tone.wash(tone || (mine ? "primary" : "dim"))

  ColumnLayout {
    id: column
    anchors.fill: parent
    anchors.leftMargin: Config.theme.itemPaddingX
    anchors.rightMargin: Config.theme.itemPaddingX
    anchors.topMargin: Config.theme.itemPaddingY
    anchors.bottomMargin: Config.theme.itemPaddingY
    spacing: Config.theme.spacing / 2
  }
}
