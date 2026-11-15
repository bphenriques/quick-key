import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui
import qs.builtins

// Status line for a menu status id (`status` in programs.quick-key.settings.menu.entries), or an icon and label without one.
StatusLine {
  id: root

  required property string status
  property string fallback: ""
  property string fallbackDetail: ""
  property var fallbackGlyphs: []
  property string icon: ""
  property bool quiet: false
  property bool active: false
  property var pins: []
  // Only the glyph and detail, e.g. on or off, without the text.
  property bool compact: false

  readonly property var builtin: Statuses.builtin[status] ?? null
  readonly property var plugin: builtin ? null : Plugins.get(status)
  readonly property var value: builtin ? builtin.value((id, name) => root.pinned(id, name), quiet) : { text: plugin?.text ?? "", detail: plugin?.detail ?? "" }

  glyph: !status ? icon : builtin ? builtin.glyph() : plugin?.glyph ?? ""
  // In the header an icon sits closer to its own text than to its neighbours.
  spacing: quiet ? Config.theme.spacing / 2 : Config.theme.spacing
  text: compact ? "" : value.text || fallback
  detail: value.detail || fallbackDetail
  detailGlyphs: value.glyphs ?? fallbackGlyphs
  detailChars: compact ? builtin?.detailChars ?? 0 : 0
  // Dim only in the header: a row dims when it cannot run (ListItem), never for having nothing to report.
  tone: plugin?.tone || (builtin?.tone ? builtin.tone() : "") || (active || quiet && plugin?.active ? "primary" : quiet ? "dim" : "normal")

  // Only in its own level: beside the volume on the top row it reads as a picture of that number.
  Meter {
    visible: root.compact && !!root.builtin?.meter
    // A neighbour, not part of the value: the full gap, half of it from the row.
    Layout.leftMargin: Config.theme.spacing / 2
    Layout.preferredWidth: Config.theme.meterLength
    value: root.builtin?.meter ? root.builtin.meter() : 0
  }

  function pinned(id, name) {
    return Array.from(pins).find(pin => MenuKeys.glob(pin.match, id))?.label ?? name;
  }
}
