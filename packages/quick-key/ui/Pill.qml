import QtQuick
import QtQuick.Layouts
import qs

// A rounded capsule around a row of content, centred on its line, outlined like a panel, or in its tone for a state (recording).
Surface {
  id: root

  property string tone: ""
  property real padding: Config.theme.spacing
  default property alias content: row.data

  implicitWidth: row.implicitWidth + 2 * padding
  implicitHeight: row.implicitHeight + padding
  // A capsule, unless the theme squares its corners.
  radius: Math.min(height / 2, 2 * Config.theme.radius)
  border.color: tone ? Tone.color(tone) : Config.colors.border

  RowLayout {
    id: row
    anchors.centerIn: parent
    spacing: Config.theme.spacing
  }
}
