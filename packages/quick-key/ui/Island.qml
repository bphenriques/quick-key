import QtQuick
import qs

// One surface of a Stack: its content on a Surface, or on one behind each item the content lists in `parts` while `split`.
QtObject {
  // What the Stack's `focus` names to give it the keys.
  property string name
  property Component content
  property bool shown: true
  // Above and below the content; its sides take the theme's padding plus `inset`, so a row's content lines up across islands.
  property real padding: Config.theme.padding
  property real inset: 0
  property real minimumHeight: 0
  property bool split: false
  // Cut to what the screen leaves past the other islands, when it must be.
  property bool cut: false

  signal secondaryClicked
}
