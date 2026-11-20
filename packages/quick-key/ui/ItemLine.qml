import QtQuick
import qs

// A listed item's line (a task, a device): lit and bold while in use, dim and struck through once done, its value in its own tone when it needs attention.
StatusLine {
  property bool active: false
  // Done (a ticked task): dim and struck through, though it still runs.
  property bool done: false
  // Its value's own tone (warning on a late task's date).
  property string itemTone: ""
  // Its own meter (each output's volume), lit while in use; unset, none.
  property var itemMeter: undefined

  readonly property string itemLabelTone: done ? "dim" : active ? "primary" : "normal"
  readonly property string itemValueTone: done ? "dim" : itemTone || (active ? "primary" : "dim")

  tone: itemLabelTone
  valueTone: itemValueTone
  struck: done
  strong: active
  meter: itemMeter !== undefined ? itemMeter : -1
  meterTone: active ? "primary" : "dim"
}
