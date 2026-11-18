import QtQuick
import qs

// A rounded capsule around a row of content, outlined like a panel, or in its tone for a state (recording).
Surface {
  id: root

  property string tone: ""
  property real padding: Config.theme.spacing
  default property alias content: row.data

  implicitWidth: row.implicitWidth + 2 * padding
  implicitHeight: row.implicitHeight + padding
  radius: height / 2
  border.color: tone ? Tone.color(tone) : Config.colors.border

  Row {
    id: row
    anchors.centerIn: parent
    spacing: Config.theme.spacing
  }
}
