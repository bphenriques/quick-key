import QtQuick
import qs.ui
import qs.builtins

// A menu item (LevelModel.itemOf, or a listed one): its status by name, or its icon and label without one, drawn as a listed item; on a row its label stays and the status follows as a value, in a bar the status alone.
StatusLine {
  id: root

  property var item: ({})
  // In a bar: the status alone, dim unless lit.
  property bool quiet: false
  // In a bar, an entry's own icon: its glyph alone, its value left to a tip.
  property bool glyphOnly: false

  readonly property string status: item.status ?? ""
  // The entry's own look over the status's fields ("{song}"); after a | its detail, kept whole on the right ("{title}|{when}").
  readonly property string format: item.format ?? ""
  readonly property bool active: item.active ?? false
  // An entry's own row in its level: its value follows its label, with the status's meter.
  readonly property bool inLevel: item.inLevel ?? false
  // Its value's own tone (warning on a late task's date).
  readonly property string itemTone: item.tone ?? ""
  // Built-in or a plugin's, in one shape.
  readonly property var shape: Statuses.of(status, Statuses.pinned(item))
  readonly property var value: format ? Statuses.value({}, shape.fields, format) : shape
  // Its work (Phase), drawn as every surface draws it: a spinner while working, its tone otherwise.
  readonly property bool statusBusy: shape.phase === "working"

  glyph: item.icon || shape.glyph
  image: item.image ?? ""
  iconHeld: item.iconHeld ?? false
  swatch: item.swatch ?? ""
  busy: item.busy ?? false
  squareIcon: !quiet
  title: status && !quiet ? item.desc ?? "" : ""
  text: glyphOnly ? "" : status ? value.text : item.desc ?? ""
  detail: glyphOnly ? "" : status ? value.detail : item.detail ?? ""
  detailGlyphs: status ? value.glyphs ?? [] : item.glyphs ?? []
  // The one to find first: the bar's anchor (the clock), or on a row what is in use, so colour is not all that says so.
  strong: shape.strong || (!status && active)
  keepsStrong: quiet
  // Its own meter (each output's volume), lit while in use; unset, the status's in its level, else none.
  meter: item.meter !== undefined ? item.meter : inLevel ? shape.meter : -1
  meterTone: item.meter !== undefined ? (active ? "primary" : "dim") : shape.muted ? "dim" : "primary"
  // Its own tone, but over a format, which shows other fields, the tone of the first field it shows that has one.
  readonly property string statusTone: format ? (format.match(/\{\w+\}/g) ?? []).map(field => shape.fieldTones[field.slice(1, -1)]).find(tone => tone) ?? "" : shape.tone
  // In a bar: its own tone, else lit while on; what is not lit dims, but for the strong one.
  readonly property string barTone: statusTone || Phase.tone(shape.phase) || (active || shape.active ? "primary" : strong ? "normal" : "dim")
  readonly property string ownValueTone: itemTone || statusTone || Phase.tone(shape.phase)

  // With a status, its label and icon stay plain and its value takes the tone; without one, a listed item's look.
  tone: item.done ? "dim" : quiet ? barTone : status || !active ? "normal" : "primary"
  valueTone: item.done ? "dim" : (status ? ownValueTone : itemTone) || (active ? "primary" : "dim")
  // Done (a ticked task): dim and struck through, though it still runs.
  struck: !!item.done
}
