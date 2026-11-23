import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui

// A bar item: an entry as its status or its icon (given both, the icon, the status lending its tone, spinner, tip and its value while it warns), a listed item (a tray app) as its image, or a status or plugin by name.
ListItem {
  id: root

  required property MenuModel menu
  property var item: ({})
  readonly property var entry: item.entry ?? null
  readonly property var plugin: entry ? null : Plugins.get(item.status)
  // Whether a click does anything: a name only shows, unless it is a plugin's.
  readonly property bool runs: !!(item.select || plugin || entry && (entry.cmd || entry.action || entry.submenu || entry.list || entry.view))

  // Shrinks, never grows: its text gives way before its neighbours.
  Layout.fillWidth: true
  Layout.maximumWidth: implicitWidth
  visible: !item.status || !status.blank
  enabled: runs && item.enabled !== false
  dimsWhenDisabled: runs
  onActivated: menu.activate(root.item, root.item.key)
  onSecondaryActivated: menu.openMenu(root.item)
  onScrolled: up => menu.act(root.item, up ? "Up" : "Down")

  MenuStatus {
    id: status
    visible: !!root.item.status
    quiet: true
    status: root.item.status ?? ""
    format: root.item.format ?? ""
    active: root.item.active ?? false
    icon: root.item.icon ?? ""
    // Its value beside it while its tone warns, so colour is not all that says so.
    glyphOnly: !!root.item.icon && !shape.brief && barTone !== "warning" && barTone !== "alert"
    busy: glyphOnly && statusBusy
  }

  Icon {
    visible: !root.item.status && (!!root.item.image || !!root.item.icon)
    source: root.item.image ?? ""
    glyph: root.item.icon ?? ""
    tone: root.item.active ? "primary" : root.item.image ? "normal" : "dim"
    recolour: root.item.image ? Config.theme.appIcons : "colour"
    // An image (a tray app's) as tall as the text: it fills its square, where a glyph does not.
    size: root.item.image ? Metrics.line : Config.theme.iconSize
  }

  // An app's name beside its icon (its menu's bar), an app without an icon, or how many more there are.
  Label {
    visible: !root.item.status && (root.item.named || !root.item.image && !root.item.icon)
    tone: "dim"
    text: root.item.desc ?? ""
  }

  // An icon alone is named on hover, a status showing only its glyph too (a plugin by its title); the row would lay it out, so it sits on the item itself.
  Tip {
    parent: root
    hovered: root.hovered
    text: status.glyphOnly ? [root.item.desc ?? "", status.value.text, status.value.detail].filter(part => part).join(", ")
      : root.item.status && root.item.icon ? root.item.desc ?? ""
      : root.item.status ? (status.text === "" && status.detail === "" ? root.plugin?.title ?? root.item.desc ?? "" : "")
      : !root.item.named && (!!root.item.image || !!root.item.icon) ? root.item.desc : ""
  }
}
