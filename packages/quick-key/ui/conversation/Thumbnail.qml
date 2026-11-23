import QtQuick
import QtQuick.Layouts
import qs.ui

// A picture by its file path, four lines tall and as wide as its shape, so a screenshot gets no bands.
Image {
  property string path

  visible: path !== ""
  source: path ? "file://" + path : ""
  fillMode: Image.PreserveAspectFit
  sourceSize.height: Metrics.line * 4
  Layout.preferredHeight: Metrics.line * 4
  Layout.preferredWidth: implicitHeight > 0 ? Layout.preferredHeight * implicitWidth / implicitHeight : 0
}
