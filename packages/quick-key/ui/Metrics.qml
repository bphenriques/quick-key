pragma Singleton

import QtQuick
import Quickshell
import qs

// The theme font's measures and the kit's fixed sizes, so sizes given in characters or lines agree everywhere.
Singleton {
  // A character's width, the font being monospace.
  readonly property real cell: cellMetrics.advanceWidth
  // A line's height, as a Label draws one.
  readonly property real line: fontMetrics.height
  // A row's padding across and down.
  readonly property int itemPaddingX: 8
  readonly property int itemPaddingY: 5
  // A row's height with its icon and label (a Label rounds its line up), what a level's height counts in.
  readonly property real row: Math.max(Math.ceil(line), Config.theme.iconSize) + 2 * itemPaddingY
  // A one-line prompt's height: a row's, less the padding its island has past a bar's (half the theme's), so an input island is as tall as the bar.
  readonly property real prompt: Math.max(Math.ceil(line), row - Config.theme.padding / 2)
  // The gap between columns of rows (a level's, the keys a modifier reaches).
  readonly property real columnGap: Math.max(Config.theme.padding, cell)
  // A meter's thickness, and its length in a row.
  readonly property int meterThickness: 6
  readonly property int meterLength: 48
  // The pop-up's level length and icon size, following the font: 160 and 28 at 11 points.
  readonly property int osdLength: Math.round(160 * Config.theme.fontSize / 11)
  readonly property int osdIconSize: Math.round(28 * Config.theme.fontSize / 11)

  TextMetrics {
    id: cellMetrics
    font: fontMetrics.font
    text: "0"
  }

  FontMetrics {
    id: fontMetrics
    font.family: Config.theme.monospaceFont
    font.pointSize: Config.theme.fontSize
  }
}
