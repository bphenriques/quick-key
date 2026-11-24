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
    item: row.item
    labelShown: !row.compact || glyph === "" && image === ""
    packed: inLevel && !row.hugs
  }

  Tip {
    parent: row
    hovered: row.hovered
    text: status.labelShown ? "" : row.item.desc ?? ""
  }
}
