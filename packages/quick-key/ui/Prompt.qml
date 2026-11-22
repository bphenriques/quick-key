import QtQuick
import QtQuick.Layouts
import qs

// A line of text to send: its key while it waits (a level's), else a glyph, a spinner in their place while what it sends to is busy, then the text growing to `maxLines`. Keys reach `keyPressed` first; Escape the owner leaves clears it, then asks its owner to step back (`back`). The conversation it sends to goes over it, in an Exchange; `keys` on its right say what other keys do.
RowLayout {
  id: root

  // Whether it has the keys; a click asks for them through `tapped`.
  property bool active: true
  property bool busy: false
  property var key: ""
  property string glyph: Glyphs.prompt
  property alias text: area.text
  property alias placeholder: area.placeholder
  property alias maxLines: area.maxLines
  // A legend on its right, as KeyLegend takes it; a click is `picked`.
  property var keys: []
  // A value on its right, dim (a filter's 1-9 of 14).
  property string detail: ""
  // Nothing to clear; an owner with more to clear than the text (a pasted image) says when.
  property bool empty: text === ""
  // The key and glyph column, as wide as the key's name (TAB) so the text holds still as it takes the keys, or an owner's column (a card's icon); the glyph on its left edge, where keys start.
  property real slot: Math.max(Metrics.line, keyHint.implicitWidth)

  signal keyPressed(var event)
  signal tapped
  signal cleared
  signal back
  signal picked(var key)

  // Escape's own steps: clear, then the owner's.
  function stepBack() {
    if (empty) {
      back();
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

  // Its key and its glyph share one column (`slot`).
  Item {
    Layout.alignment: Qt.AlignTop
    implicitWidth: root.slot
    implicitHeight: Metrics.line

    Spinner {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: root.busy
      tone: "dim"
      size: Metrics.line
    }

    KeyHint {
      id: keyHint
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.busy && !root.active && root.key !== ""
      key: root.key
      chars: MenuKeys.label(root.key).length
    }

    Icon {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.busy && (root.active || root.key === "")
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

  // On the text's line, unpadded, so showing it never grows the prompt.
  KeyLegend {
    Layout.alignment: Qt.AlignTop
    verticalPadding: 0
    visible: root.keys.length > 0
    keys: root.keys
    onPicked: key => root.picked(key)
  }

  Label {
    Layout.alignment: Qt.AlignTop
    visible: root.detail !== ""
    tone: "dim"
    text: root.detail
  }
}
