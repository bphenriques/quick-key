import QtQuick
import qs

// One surface of a Stack: its content on a Surface, or on one behind each item the content lists in `parts` while `split`.
QtObject {
  // What the Stack's `focus` names to give it the keys.
  property string name
  property Component content
  property bool shown: true
  // Its own width, no wider than the screen leaves; unset (-1), the Stack's.
  property real width: -1
  // Above and below the content; its sides take the theme's padding plus `inset`, so a row's content lines up across islands.
  property real padding: Config.theme.padding
  property real inset: 0
  property real minimumHeight: 0
  // While set, it keeps the tallest it has been, its content against the screen's edge, until it changes.
  property var holdKey: ""
  property bool split: false
  // Cut to what the screen leaves past the other islands, when it must be.
  property bool cut: false

  signal clicked
  signal secondaryClicked
}
