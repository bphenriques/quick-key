import QtQuick
import QtQuick.Layouts
import qs.ui

// A row of the menu: its key, its label, and what its status reports on the right.
ListItem {
  id: row

  required property MenuModel menu
  property var item: ({})
  property int chars: 1
  // As wide as its content, against the right edge (the last column of a level): nothing to pack.
  property bool hugs: false
  // On a crowded bar: its key and glyph alone, its label as its tip; without a glyph, its label stays.
  property bool compact: false
  // As wide as it is with its label, shown or not.
  readonly property real labelledWidth: implicitWidth + (status.labelShown ? 0 : status.labelWidth)

  enabled: row.item.enabled !== false
  current: !!row.item.current
  onActivated: menu.activate(row.item)
  onSecondaryActivated: menu.openMenu(row.item)
  onScrolled: up => menu.act(row.item, up ? "Up" : "Down")

  KeyHint {
    key: row.item.key ?? ""
    paired: row.item.paired ?? false
    chars: MenuKeys.gutter(row.chars)
  }

  MenuStatus {
    id: status
    Layout.fillWidth: true
    labelShown: !row.compact || glyph === "" && image === ""
    image: row.item.image ?? ""
    status: row.item.status ?? ""
    format: row.item.format ?? ""
    fallback: row.item.desc ?? ""
    fallbackDetail: row.item.detail ?? ""
    fallbackGlyphs: row.item.glyphs ?? []
    icon: row.item.icon ?? ""
    active: row.item.active ?? false
    done: row.item.done ?? false
    busy: row.item.busy ?? false
    itemTone: row.item.tone ?? ""
    pins: row.item.entry?.pins ?? []
    inLevel: row.item.inLevel ?? false
    packed: inLevel && !row.hugs
    itemMeter: row.item.meter
  }

  Tip {
    parent: row
    hovered: row.hovered
    text: status.labelShown ? "" : row.item.desc ?? ""
  }
}
