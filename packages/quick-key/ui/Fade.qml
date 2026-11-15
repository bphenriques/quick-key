import QtQuick
import qs

// `value` follows `shown` over theme.animationDuration; `loaded` holds until faded out, so leaving is seen, not cut.
Item {
  property bool shown: false
  property real value: shown ? 1 : 0
  readonly property bool loaded: value > 0

  Behavior on value {
    NumberAnimation {
      duration: Config.theme.animationDuration
    }
  }
}
