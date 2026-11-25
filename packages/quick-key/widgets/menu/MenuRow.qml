import QtQuick
import QtQuick.Layouts
import qs.ui

// A row of the menu: its key, its label, and what its status reports on the right.
ListItem {
  id: row

  required property MenuModel menu
  // The island's level it sits on, which a click gives the keys and acts on.
  required property LevelModel level
  property var item: ({})
  property int chars: 1
  // As wide as its content, against the right edge (the last column of a level): nothing to pack.
  property bool hugs: false
  // On a crowded bar: its key and glyph alone, its label and value as its tip; without a glyph, its label stays, and its value while it warns.
  property bool compact: false
  // Its key dims while its island does not have the keys.
  property bool live: row.level.focused

  enabled: row.item.enabled !== false
  current: !!row.item.current
  onActivated: menu.click(row.item, row.level)
  onSecondaryActivated: menu.secondaryClick(row.item, row.level)
  onScrolled: up => menu.act(row.item, up, row.level)

  KeyHint {
    key: row.item.key ?? ""
    paired: row.item.paired ?? false
    chars: MenuKeys.gutter(row.chars)
    live: row.live
  }

  MenuStatus {
    id: status
    Layout.fillWidth: true
    item: row.item
    labelShown: !row.compact || glyph === "" && image === ""
    glyphOnly: !labelShown && ownValueTone !== "warning" && ownValueTone !== "alert"
    packed: inLevel && !row.hugs
  }

  Tip {
    parent: row
    hovered: row.hovered
    text: status.labelShown ? "" : [row.item.desc ?? ""].concat(row.item.status ? [status.value.text, status.value.detail] : [row.item.detail]).filter(part => part).join(", ")
  }
}
