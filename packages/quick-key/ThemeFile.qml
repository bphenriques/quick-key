import QtQuick
import Quickshell
import Quickshell.Io

// A theme's colours; a change reloads the shell, so removed colours fall back too.
FileView {
  readonly property alias palette: adapter
  property bool missing: false

  watchChanges: true
  printErrors: false
  onFileChanged: Quickshell.reload(false)
  onLoaded: missing = false
  onLoadFailed: missing = true

  JsonAdapter {
    id: adapter
    property string background
    property string foreground
    property string primary
    property string alert
    property string warning
  }
}
