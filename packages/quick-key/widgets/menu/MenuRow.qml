import QtQuick
import QtQuick.Layouts
import qs.ui

// A row of the menu: its key, then its status or label.
ListItem {
  id: row

  required property MenuModel menu
  required property var modelData
  property int chars: 1

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
    fallback: row.modelData.desc
    fallbackDetail: row.modelData.detail ?? ""
    fallbackGlyphs: row.modelData.glyphs ?? []
    icon: row.modelData.icon ?? ""
    active: row.modelData.active ?? false
    pins: row.modelData.entry?.pins ?? []
  }
}
