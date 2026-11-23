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
  // Tinting flattens an image to its shape, so only a symbolic icon (one colour by design) is tinted; a full-colour one goes grey instead.
  readonly property string drawn: recolour === "tint" && !source.includes("symbolic") ? "grey" : recolour

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
    id: image
    anchors.fill: parent
    // Tinted, it is only the shape the tone fills.
    visible: root.source !== "" && root.drawn !== "tint"
    source: root.source
    layer.enabled: root.drawn !== "colour"
    layer.effect: MultiEffect {
      saturation: root.drawn === "grey" ? -1 : 0
    }
    // An image has no colour to dim, so a dim one fades instead.
    opacity: root.tone === "dim" ? Config.theme.dimOpacity : 1

    Behavior on opacity {
      NumberAnimation {
        duration: Config.theme.animationDuration
      }
    }
  }

  // The tone's colour through the image's shape, so a white symbolic icon reads on a light theme.
  Rectangle {
    anchors.fill: parent
    visible: root.source !== "" && root.drawn === "tint"
    color: glyphLabel.color
    layer.enabled: visible
    layer.effect: MultiEffect {
      maskEnabled: true
      maskSource: image
      // Its opaque pixels, edges softened: at 0, transparent ones would pass too.
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }
  }
}
