pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import Quickshell.Widgets
import qs

// A font glyph or an image (e.g. a tray app's icon) in the same square, so rows line up either way.
Item {
  id: root

  property string glyph: ""
  property string source: ""
  property string tone: "normal"
  property real size: Config.theme.iconSize
  // An image as drawn ("colour"), in greys ("grey"), or as its shape in the tone's colour ("tint").
  property string recolour: "colour"

  visible: glyph !== "" || source !== ""
  implicitWidth: size
  implicitHeight: size

  Label {
    id: glyphLabel
    anchors.centerIn: parent
    visible: root.source === ""
    tone: root.tone
    // A point is 4/3 of a pixel, so the glyph fills the square. Bindings can read the size before it is set; Qt rejects a zero point size.
    font.pointSize: Math.max(1, root.size * 0.75)
    text: root.glyph
  }

  IconImage {
    anchors.fill: parent
    visible: root.source !== ""
    source: root.source
    layer.enabled: root.recolour !== "colour"
    layer.effect: MultiEffect {
      saturation: root.recolour === "grey" ? -1 : 0
      // Brightened to white first, so the colour is the tone's whatever the icon's own.
      brightness: root.recolour === "tint" ? 1 : 0
      colorization: root.recolour === "tint" ? 1 : 0
      colorizationColor: glyphLabel.color
    }
    // An image has no colour to dim, so a dim one fades instead.
    opacity: root.tone === "dim" ? Config.theme.dimOpacity : 1

    Behavior on opacity {
      NumberAnimation {
        duration: Config.theme.animationDuration
      }
    }
  }
}
