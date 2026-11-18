import QtQuick
import QtQuick.Effects

// A shadow like niri's default, for a surface drawn inside a larger window: only outside the surface, so what shows through it (blur) stays clear.
Item {
  id: root

  property real radius
  // Room for the blur, spread and offset beyond the surface.
  readonly property real reach: 48

  Item {
    id: canvas
    anchors.fill: parent
    anchors.margins: -root.reach
    layer.enabled: true
    layer.effect: MultiEffect {
      maskEnabled: true
      maskInverted: true
      maskSource: cutout
      maskThresholdMin: 0.5
      maskSpreadAtMin: 1
    }

    RectangularShadow {
      x: root.reach
      y: root.reach
      width: root.width
      height: root.height
      radius: root.radius
      offset.y: 5
      spread: 5
      blur: 30
      color: "#77000000"
    }
  }

  // The surface's own shape, cut out of the shadow.
  Item {
    id: cutout
    anchors.fill: canvas
    visible: false
    layer.enabled: true

    Rectangle {
      x: root.reach
      y: root.reach
      width: root.width
      height: root.height
      radius: root.radius
    }
  }
}
