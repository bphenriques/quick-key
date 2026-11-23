import QtQuick
import qs

// `value` follows `shown` over theme.animationDuration, and a sliding surface's `distance`; `loaded` holds until faded out, so leaving is seen, not cut.
Item {
  property bool shown: false
  property real value: shown ? 1 : 0
  readonly property bool loaded: value > 0
  // With `theme.motion` "slide", how far a surface travels in from its edge as `value` rises; else 0. A surface makes its window that much larger on that side, so it never slides past its own edge.
  readonly property real distance: Config.theme.motion === "slide" ? 2 * Metrics.line : 0

  Behavior on value {
    NumberAnimation {
      duration: Config.theme.animationDuration
    }
  }
}
