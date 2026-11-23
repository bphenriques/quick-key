import QtQuick
import qs
import qs.services
import qs.ui
import qs.builtins

// A status by name (`status` in an entry), or an icon and label without one, drawn as a listed item: lit and bold while in use, dim and struck through once done. On a row its label stays and the status follows as a value; in a bar the status alone.
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

  readonly property var builtin: Statuses.builtin[status] ?? null
  readonly property var plugin: builtin ? null : Plugins.get(status)
  readonly property var fields: builtin ? builtin.fields((id, name) => root.pinned(id, name)) : Object.assign({ text: plugin?.text ?? "", detail: plugin?.detail ?? "" }, plugin?.fields ?? {})
  readonly property var value: builtin || format ? Statuses.value(builtin ?? {}, fields, format) : { text: plugin?.text ?? "", detail: plugin?.detail ?? "", glyphs: Array.from(plugin?.glyphs ?? []) }
  readonly property string statusTone: plugin?.tone || (builtin?.tone ? builtin.tone() : "")
  // Its work (Phase), drawn as every surface draws it: a spinner while working, its tone otherwise.
  readonly property string statusPhase: builtin?.phase ? builtin.phase() : plugin?.phase ?? "idle"
  readonly property bool statusBusy: statusPhase === "working"
  readonly property bool blank: glyph === "" && text === "" && detail === ""

  glyph: icon || Statuses.glyphOf(status)
  // In a bar an icon sits closer to its own text than to its neighbours.
  spacing: quiet ? Config.theme.spacing / 2 : Config.theme.spacing
  title: status && !quiet ? fallback : ""
  text: glyphOnly ? "" : status ? value.text : fallback
  detail: glyphOnly ? "" : status ? value.detail : fallbackDetail
  detailGlyphs: status ? value.glyphs ?? [] : fallbackGlyphs
  // The one to find first: the bar's anchor (the clock), or on a row what is in use, so colour is not all that says so.
  strong: !!builtin?.strong || (!status && active)
  // The clock is a title in a bar only: in a body every row is one size.
  heading: quiet && !!builtin?.strong
  meter: itemMeter !== undefined ? itemMeter : inLevel && builtin?.meter ? builtin.meter() : -1
  meterTone: itemMeter !== undefined ? (active ? "primary" : "dim") : builtin?.muted && builtin.muted() ? "dim" : "primary"
  // In a bar: its own tone (over a format, a field's it shows), else lit while on; what is not lit dims, but for the strong one.
  readonly property string barTone: (format ? formatTone : statusTone) || Phase.tone(statusPhase) || (active || plugin?.active ? "primary" : strong ? "normal" : "dim")
  // A status's tone is its own value's, but not over a format, which shows other fields.
  readonly property string ownValueTone: itemTone || (format ? formatTone : statusTone) || Phase.tone(statusPhase)
  // Under a format, the tone of a field it shows, when one has its own.
  readonly property var fieldTones: builtin?.fieldTones ? builtin.fieldTones() : plugin?.fieldTones ?? {}
  readonly property string formatTone: format ? (format.match(/\{\w+\}/g) ?? []).map(field => fieldTones[field.slice(1, -1)]).find(tone => tone) ?? "" : ""

  // With a status, its label and icon stay plain and its value takes the tone; without one, a listed item's look.
  tone: done ? "dim" : quiet ? barTone : status || !active ? "normal" : "primary"
  valueTone: done ? "dim" : (status ? ownValueTone : itemTone) || (active ? "primary" : "dim")
  struck: done

  function pinned(id, name) {
    return Array.from(pins).find(pin => MenuKeys.glob(pin.match, id))?.label ?? name;
  }
}
