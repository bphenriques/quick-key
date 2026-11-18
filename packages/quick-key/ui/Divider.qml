import QtQuick
import QtQuick.Window
import qs

// A thin line between two groups of rows, in the outline's colour.
Rectangle {
  // As thin as an outline, across a column or down a row.
  readonly property real thickness: Config.theme.borderWidth / Screen.devicePixelRatio

  implicitHeight: thickness
  implicitWidth: thickness
  color: Config.colors.border
}
