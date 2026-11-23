import QtQuick
import Quickshell
import qs

// A region over `over` at the place its holder gives (`at`, in the window), empty while it hides: given by `item`, a region follows the item alone, not what moves it.
Region {
  property Item over: null
  property point at: Qt.point(0, 0)
  readonly property bool shows: over?.visible ?? false

  x: shows ? at.x : 0
  y: shows ? at.y : 0
  width: shows ? over.width : 0
  height: shows ? over.height : 0
  radius: Config.theme.radius
}
