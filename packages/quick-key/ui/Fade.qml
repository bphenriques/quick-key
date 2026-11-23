import QtQuick
import qs

// `value` follows `shown` over theme.animationDuration, and `offset` with it for a sliding surface; `loaded` holds until faded out, so leaving is seen, not cut.
Item {
  property bool shown: false
  property real value: shown ? 1 : 0
  readonly property bool loaded: value > 0
  // With `theme.motion` "slide", how far a surface still has to travel in from its edge, toward 0 as it shows; else 0.
  readonly property real offset: Config.theme.motion === "slide" ? (1 - value) * 2 * Metrics.line : 0

  Behavior on value {
    NumberAnimation {
      duration: Config.theme.animationDuration
    }
  }
}
