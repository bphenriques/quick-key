import QtQuick
import QtQuick.Layouts
import qs

// A line of text to send: its key while it waits (a level's), else a glyph, then the text growing to `maxLines`. Keys reach `keyPressed` first; Escape the owner leaves clears it, then gives the keys back (`unfocused`, `stepBack`).
RowLayout {
  id: root

  // Whether it has the keys; a click asks for them through `tapped`.
  property bool active: true
  property var key: ""
  property string glyph: Glyphs.submenu
  property alias text: area.text
  property alias placeholder: area.placeholder
  property alias maxLines: area.maxLines
  // Nothing to clear; an owner with more to clear than the text (a pasted image) says when.
  property bool empty: text === ""

  signal keyPressed(var event)
  signal tapped
  signal cleared
  signal unfocused

  // Escape's own steps: clear, then give the keys back.
  function stepBack() {
    if (empty) {
      unfocused();
      return;
    }
    area.clear();
    cleared();
  }

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
    onKeyPressed: event => {
      root.keyPressed(event);
      if (!event.accepted && event.key === Qt.Key_Escape) {
        root.stepBack();
        event.accepted = true;
      }
    }

    TapHandler {
      enabled: !root.active
      onTapped: root.tapped()
    }
  }
}
