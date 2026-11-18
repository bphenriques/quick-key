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

  enabled: row.item.enabled !== false
  onActivated: menu.activate(row.item)
  onSecondaryActivated: menu.openMenu(row.item)
  onScrolled: up => menu.act(row.item, up ? "Up" : "Down")

  KeyHint {
    key: row.item.key ?? ""
    paired: row.item.paired ?? false
    chars: row.chars
  }

  MenuStatus {
    Layout.fillWidth: true
    image: row.item.image ?? ""
    status: row.item.status ?? ""
    format: row.item.format ?? ""
    fallback: row.item.desc ?? ""
    fallbackDetail: row.item.detail ?? ""
    fallbackGlyphs: row.item.glyphs ?? []
    icon: row.item.icon ?? ""
    active: row.item.active ?? false
    done: row.item.done ?? false
    itemTone: row.item.tone ?? ""
    pins: row.item.entry?.pins ?? []
    inLevel: row.item.inLevel ?? false
    packed: inLevel && !row.hugs
    listedMeter: row.item.meter
  }
}
