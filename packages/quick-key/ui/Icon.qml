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
  // Still being made: in its place the braille dots terminals turn, at their own tempo; still when animations are off.
  property bool busy: false
  // Off where it stands in no column (a bar): a glyph as wide as its ink, so it meets the padding as a letter does, whatever cell its font gives it.
  property bool square: true

  visible: busy || glyph !== "" || source !== ""
  // The glyph's, held while the dots turn in its place.
  implicitWidth: square || source !== "" ? size : Metrics.glyphWidth(glyph, size)
  implicitHeight: size

  Timer {
    id: turning
    property int frame: 0
    running: root.busy && root.visible && Config.theme.animationDuration > 0
    interval: 80
    repeat: true
    onTriggered: frame = (frame + 1) % 10
  }

  Label {
    id: glyphLabel
    anchors.centerIn: parent
    visible: root.busy || root.source === ""
    tone: root.tone
    // A point is 4/3 of a pixel, so a glyph is as tall as the square (a Mono font's is a cell wide) and the dots clear a pill's border. Bindings can read the size before it is set; Qt rejects a zero point size.
    font.pointSize: Math.max(1, root.size * (root.busy ? 0.7 : 1) * 0.75)
    text: root.busy ? "⠋⠙⠹⠸⠼⠴⠦⠧⠇⠏"[turning.frame] : root.glyph
  }

  IconImage {
    id: image
    anchors.fill: parent
    // Tinted, it is only the shape the tone fills.
    visible: !root.busy && root.source !== "" && root.drawn !== "tint"
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
    visible: !root.busy && root.source !== "" && root.drawn === "tint"
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
