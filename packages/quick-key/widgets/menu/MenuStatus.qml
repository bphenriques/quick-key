import QtQuick
import qs
import qs.ui
import qs.builtins

// A status by name (`status` in an entry), or an icon and label without one, drawn as a listed item; on a row its label stays and the status follows as a value, in a bar the status alone.
StatusLine {
  id: root

  property bool active: false
  // Done (a ticked task): dim and struck through, though it still runs.
  property bool done: false
  // Its value's own tone (warning on a late task's date).
  property string itemTone: ""
  // Its own meter (each output's volume), lit while in use; unset, none.
  property var itemMeter: undefined
  required property string status
  // The entry's own look over the status's fields ("{song}"); after a | its detail, kept whole on the right ("{title}|{when}").
  property string format: ""
  property string fallback: ""
  property string fallbackDetail: ""
  property var fallbackGlyphs: []
  property string icon: ""
  // In a bar: the status alone, dim unless lit.
  property bool quiet: false
  // In a bar, an entry's own icon: its glyph alone, its value left to a tip.
  property bool glyphOnly: false
  property var pins: []
  // An entry's own row in its level: its value follows its label, with the status's meter.
  property bool inLevel: false

  // Built-in or a plugin's, in one shape.
  readonly property var shape: Statuses.of(status, (id, name) => root.pinned(id, name))
  readonly property var value: format ? Statuses.value({}, shape.fields, format) : shape
  // Its work (Phase), drawn as every surface draws it: a spinner while working, its tone otherwise.
  readonly property bool statusBusy: shape.phase === "working"
  readonly property bool blank: glyph === "" && text === "" && detail === ""

  glyph: icon || shape.glyph
  // In a bar an icon sits closer to its own text than to its neighbours.
  spacing: quiet ? Config.theme.spacing / 2 : Config.theme.spacing
  title: status && !quiet ? fallback : ""
  text: glyphOnly ? "" : status ? value.text : fallback
  detail: glyphOnly ? "" : status ? value.detail : fallbackDetail
  detailGlyphs: status ? value.glyphs ?? [] : fallbackGlyphs
  // The one to find first: the bar's anchor (the clock), or on a row what is in use, so colour is not all that says so.
  strong: shape.strong || (!status && active)
  meter: itemMeter !== undefined ? itemMeter : inLevel ? shape.meter : -1
  meterTone: itemMeter !== undefined ? (active ? "primary" : "dim") : shape.muted ? "dim" : "primary"
  // Its own tone, but over a format, which shows other fields, the tone of the first field it shows that has one.
  readonly property string statusTone: format ? (format.match(/\{\w+\}/g) ?? []).map(field => shape.fieldTones[field.slice(1, -1)]).find(tone => tone) ?? "" : shape.tone
  // In a bar: its own tone, else lit while on; what is not lit dims, but for the strong one.
  readonly property string barTone: statusTone || Phase.tone(shape.phase) || (active || shape.active ? "primary" : strong ? "normal" : "dim")
  readonly property string ownValueTone: itemTone || statusTone || Phase.tone(shape.phase)

  // With a status, its label and icon stay plain and its value takes the tone; without one, a listed item's look.
  tone: done ? "dim" : quiet ? barTone : status || !active ? "normal" : "primary"
  valueTone: done ? "dim" : (status ? ownValueTone : itemTone) || (active ? "primary" : "dim")
  struck: done

  function pinned(id, name) {
    return Array.from(pins).find(pin => MenuKeys.glob(pin.match, id))?.label ?? name;
  }
}
