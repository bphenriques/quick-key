import QtQuick
import QtQuick.Layouts
import qs
import qs.builtins
import qs.services
import qs.ui

// A header item by name: built in, or a plugin's. A click does what its compositor key does, shown while Super is held.
ListItem {
  id: item

  required property MenuModel menu
  required property string modelData
  readonly property var builtin: HeaderItems.builtin[modelData] ?? null
  readonly property var plugin: builtin ? null : Plugins.get(modelData)
  readonly property string shortcut: plugin?.shortcut ?? Config[modelData]?.shortcut ?? ""

  // Shrinks, never grows: its text gives way before its neighbours.
  Layout.fillWidth: true
  Layout.maximumWidth: implicitWidth
  visible: builtin ? builtin.shown() : plugin !== null
  enabled: !builtin || (builtin.enabled ? builtin.enabled(menu) : !!builtin.activate)
  dimsWhenDisabled: false
  onActivated: builtin ? builtin.activate(menu) : plugin?.activate()

  KeyHint {
    visible: item.menu.shortcutsShown && item.shortcut !== ""
    key: item.shortcut
    chars: MenuKeys.label(item.shortcut).length
  }

  Label {
    visible: !!item.builtin?.label
    Layout.fillWidth: true
    elide: Text.ElideRight
    font.bold: true
    text: item.builtin?.label ? item.builtin.label() : ""
  }

  MenuStatus {
    visible: !item.builtin?.label
    quiet: true
    status: item.builtin?.label ? "" : item.modelData
  }
}
