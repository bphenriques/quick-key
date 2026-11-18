import QtQuick
import QtQuick.Layouts
import qs

// A line of text to send: its key while it waits (a level's), else a glyph, then the text growing to `maxLines`; keys reach `keyPressed` first.
RowLayout {
  id: root

  // Whether it has the keys; a click asks for them through `tapped`.
  property bool active: true
  property var key: ""
  property string glyph: Glyphs.submenu
  property alias text: area.text
  property alias placeholder: area.placeholder
  property alias maxLines: area.maxLines

  signal keyPressed(var event)
  signal tapped

  function clear() {
    area.clear();
  }

  function paste() {
    area.paste();
  }

  function set(text) {
    area.set(text);
  }

  spacing: Config.theme.spacing

  // Its key and its glyph share one square, so the text holds still as it takes the keys.
  Item {
    Layout.alignment: Qt.AlignTop
    implicitWidth: Metrics.line
    implicitHeight: Metrics.line

    KeyHint {
      anchors.centerIn: parent
      visible: !root.active && root.key !== ""
      key: root.key
      chars: MenuKeys.label(root.key).length
    }

    Icon {
      anchors.centerIn: parent
      visible: root.active || root.key === ""
      tone: root.active ? "primary" : "dim"
      glyph: root.glyph
      size: Metrics.line
    }
  }

  TextArea {
    id: area
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    activeFocusOnPress: root.active
    onKeyPressed: event => root.keyPressed(event)

    TapHandler {
      enabled: !root.active
      onTapped: root.tapped()
    }
  }
}
