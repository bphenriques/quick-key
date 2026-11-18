import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui

// An item of a bar (its keys are listed in the body while Ctrl is held): an entry as its status or else its icon, a listed item (a tray app) as its image, or a status or plugin by name.
ListItem {
  id: item

  required property MenuModel menu
  required property var modelData
  readonly property var entry: modelData.entry ?? null
  readonly property var plugin: entry ? null : Plugins.get(modelData.status)
  // Whether a click does anything: a name only shows, unless it is a plugin's.
  readonly property bool runs: !!(modelData.select || plugin || entry && (entry.cmd || entry.action || entry.submenu || entry.list || entry.view))

  // Shrinks, never grows: its text gives way before its neighbours.
  Layout.fillWidth: true
  Layout.maximumWidth: implicitWidth
  visible: !modelData.status || !status.blank
  enabled: runs && modelData.enabled !== false
  dimsWhenDisabled: runs
  onActivated: menu.activate(modelData, modelData.key)
  onSecondaryActivated: menu.openMenu(modelData)
  onScrolled: up => menu.act(modelData, up ? "Up" : "Down")

  MenuStatus {
    id: status
    visible: !!item.modelData.status
    quiet: true
    status: item.modelData.status ?? ""
    format: item.modelData.format ?? ""
    active: item.modelData.active ?? false
  }

  Icon {
    visible: !item.modelData.status && (!!item.modelData.image || !!item.modelData.icon)
    source: item.modelData.image ?? ""
    glyph: item.modelData.icon ?? ""
    tone: item.modelData.active ? "primary" : item.modelData.image ? "normal" : "dim"
    monochrome: !!item.modelData.image && Config.theme.monochromeTray
  }

  // An app's name beside its icon (its menu's bar), an app without an icon, or how many more there are.
  Label {
    visible: !item.modelData.status && (item.modelData.named || !item.modelData.image && !item.modelData.icon)
    tone: "dim"
    text: item.modelData.desc
  }

  // An icon alone is named on hover; the row would lay it out, so it sits on the item itself.
  Tip {
    parent: item
    hovered: item.hovered
    text: !item.modelData.status && !item.modelData.named && (!!item.modelData.image || !!item.modelData.icon) ? item.modelData.desc : ""
  }
}
