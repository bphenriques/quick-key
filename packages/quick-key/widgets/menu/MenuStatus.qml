import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui
import qs.builtins

// A status by name (`status` in an entry), or an icon and label without one. On a row its label stays and the status follows as a value; in a bar the status alone.
StatusLine {
  id: root

  required property string status
  // The entry's own look over the status's fields ("{song}"); after a | its detail, kept whole on the right ("{title}|{when}").
  property string format: ""
  property string fallback: ""
  property string fallbackDetail: ""
  property var fallbackGlyphs: []
  property string icon: ""
  // In a bar: the status alone, dim unless lit.
  property bool quiet: false
  property bool active: false
  // A listed item that is done (a ticked task): dim and struck through, though it still runs.
  property bool done: false
  // A listed item's own tone for its value (warning on a late task's date), over its status's.
  property string itemTone: ""
  property var pins: []
  // An entry's own row in its level: its value follows its label, with the status's meter; a listed item brings its own meter (each output's volume).
  property bool inLevel: false
  property var listedMeter: undefined

  readonly property var builtin: Statuses.builtin[status] ?? null
  readonly property var plugin: builtin ? null : Plugins.get(status)
  readonly property var fields: builtin ? builtin.fields((id, name) => root.pinned(id, name)) : Object.assign({ text: plugin?.text ?? "", detail: plugin?.detail ?? "" }, plugin?.fields ?? {})
  readonly property var value: format ? { text: Statuses.formatted(format.split("|")[0], fields), detail: Statuses.formatted(format.split("|")[1] ?? "", fields) } : builtin ? builtin.value(fields) : { text: plugin?.text ?? "", detail: plugin?.detail ?? "", glyphs: Array.from(plugin?.glyphs ?? []) }
  readonly property string statusTone: plugin?.tone || (builtin?.tone ? builtin.tone() : "")
  readonly property bool blank: glyph === "" && text === "" && detail === ""

  glyph: icon || (builtin ? builtin.glyph() : plugin?.glyph ?? "")
  // In a bar an icon sits closer to its own text than to its neighbours.
  spacing: quiet ? Config.theme.spacing / 2 : Config.theme.spacing
  title: status && !quiet ? fallback : ""
  text: status ? value.text : fallback
  detail: status ? value.detail : fallbackDetail
  detailGlyphs: status ? value.glyphs ?? [] : fallbackGlyphs
  struck: done
  strong: !!builtin?.strong
  meter: listedMeter !== undefined ? listedMeter : inLevel && builtin?.meter ? builtin.meter() : -1
  // A listed item's meter is lit while it is in use, like its value.
  meterTone: listedMeter !== undefined ? (active ? "primary" : "dim") : builtin?.muted && builtin.muted() ? "dim" : "primary"
  // In a bar: its own tone, else lit while on; what is not lit dims, but for the strong one.
  readonly property string barTone: statusTone || (active || plugin?.active ? "primary" : strong ? "normal" : "dim")
  // On a row: a listed item in use is lit whole; a status leaves its label and icon plain, its value taking the tone.
  readonly property string rowTone: !status && active ? "primary" : "normal"
  // A status's tone is its own value's, but not over a format, which shows other fields.
  readonly property string ownValueTone: itemTone || (format ? "" : statusTone)

  tone: done ? "dim" : quiet ? barTone : rowTone
  valueTone: done ? "dim" : ownValueTone || (active ? "primary" : "dim")

  function pinned(id, name) {
    return Array.from(pins).find(pin => MenuKeys.glob(pin.match, id))?.label ?? name;
  }
}
