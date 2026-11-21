import QtQuick
import qs

// A one-cell wait: the braille dots terminals turn, at their own tempo; still when animations are off.
Item {
  id: root

  property string tone: "normal"
  property real size: Config.theme.iconSize

  readonly property var frames: ["⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"]
  property int frame: 0

  implicitWidth: size
  implicitHeight: size

  Timer {
    running: root.visible && Config.theme.animationDuration > 0
    interval: 80
    repeat: true
    onTriggered: root.frame = (root.frame + 1) % root.frames.length
  }

  // Sized to sit inside `size`, clear of a pill's border.
  Label {
    anchors.centerIn: parent
    tone: root.tone
    // A point is 4/3 of a pixel.
    font.pointSize: Math.max(1, root.size * 0.7 * 0.75)
    text: root.frames[root.frame]
  }
}
