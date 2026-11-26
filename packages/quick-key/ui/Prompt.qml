import QtQuick
import QtQuick.Layouts
import qs

// A line of text to send: its key while it waits, else a glyph or a spinner, then the text growing to `maxLines`; Escape the owner leaves clears it, then emits `back`.
RowLayout {
  id: root

  // Whether it has the keys; a click asks for them through `tapped`.
  property bool focused: true
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
  // The key and glyph column, as wide as the key's name (TAB) so the text holds still as it takes the keys, or an owner's column (a card's icon); the glyph on its left edge, where keys start.
  property real slot: Math.max(Metrics.line, keyHint.implicitWidth)
  // Return sends its text (`sent`), in the background with Ctrl+Shift, Shift+Return breaking the line; off, Return reaches `keyPressed` (a filter's).
  property bool sends: true
  // Above and below its text, so one line is `Metrics.prompt` tall and more grow by lines.
  readonly property real margin: (Metrics.prompt - Math.ceil(Metrics.line)) / 2

  signal sent(bool background)
  signal keyPressed(var event)
  signal tapped
  signal back
  signal picked(var key)

  // Escape's own steps: clear, then the owner's.
  function stepBack() {
    if (text === "") back();
    else area.clear();
  }

  function clear() {
    area.clear();
  }

  function set(text, selected) {
    area.set(text, selected);
  }

  spacing: Config.theme.spacing

  // Its key and its glyph share one column (`slot`).
  Item {
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: root.margin
    implicitWidth: root.slot
    implicitHeight: Metrics.line

    KeyHint {
      id: keyHint
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: !root.busy && !root.focused && root.key !== ""
      key: root.key
    }

    Icon {
      anchors.left: parent.left
      anchors.verticalCenter: parent.verticalCenter
      visible: root.busy || root.focused || root.key === ""
      busy: root.busy
      tone: root.focused && !root.busy ? "primary" : "dim"
      glyph: root.glyph
      size: Metrics.line
    }
  }

  TextArea {
    id: area
    Layout.fillWidth: true
    Layout.preferredHeight: implicitHeight
    Layout.topMargin: root.margin
    Layout.bottomMargin: root.margin
    activeFocusOnPress: root.focused
    onKeyPressed: event => {
      const send = root.sends ? MenuKeys.sends(event) : "";
      if (send) {
        root.sent(send === "background");
        event.accepted = true;
        return;
      }
      root.keyPressed(event);
      if (!event.accepted && event.key === Qt.Key_Escape) {
        root.stepBack();
        event.accepted = true;
      }
    }

    TapHandler {
      enabled: !root.focused
      onTapped: root.tapped()
    }
  }

  // On the text's line, unpadded, so showing it never grows the prompt.
  KeyLegend {
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: root.margin
    verticalPadding: 0
    visible: root.keys.length > 0
    keys: root.keys
    onPicked: key => root.picked(key)
  }

  Label {
    Layout.alignment: Qt.AlignTop
    Layout.topMargin: root.margin
    visible: root.detail !== ""
    tone: "dim"
    text: root.detail
  }
}
