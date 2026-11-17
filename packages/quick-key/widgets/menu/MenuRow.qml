import QtQuick
import QtQuick.Layouts
import qs.ui

// A row of the menu: its key, its label, and what its status reports on the right.
ListItem {
  id: row

  required property MenuModel menu
  required property var modelData
  property int chars: 1
  // As wide as its content, against the right edge (the last column of a level): nothing to pack.
  property bool hugs: false

  enabled: modelData.enabled !== false
  onActivated: menu.activate(modelData)
  onSecondaryActivated: menu.openMenu(modelData)
  onScrolled: up => menu.act(modelData, up ? "Up" : "Down")

  KeyHint {
    key: row.modelData.key
    paired: row.modelData.paired ?? false
    chars: row.chars
  }

  MenuStatus {
    Layout.fillWidth: true
    image: row.modelData.image ?? ""
    status: row.modelData.status ?? ""
    format: row.modelData.format ?? ""
    fallback: row.modelData.desc
    fallbackDetail: row.modelData.detail ?? ""
    fallbackGlyphs: row.modelData.glyphs ?? []
    icon: row.modelData.icon ?? ""
    active: row.modelData.active ?? false
    done: row.modelData.done ?? false
    itemTone: row.modelData.tone ?? ""
    pins: row.modelData.entry?.pins ?? []
    inLevel: row.modelData.inLevel ?? false
    packed: inLevel && !row.hugs
    listedMeter: row.modelData.meter
  }
}
