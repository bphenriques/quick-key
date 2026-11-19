import QtQuick
import QtQuick.Layouts
import qs

// A line of text to send: its key while it waits (a level's), else a glyph, a spinner in their place while what it sends to is busy, then the text growing to `maxLines`; over it, what was said about it (`note`). Keys reach `keyPressed` first; Escape the owner leaves clears it, then gives the keys back (`unfocused`, `stepBack`).
ColumnLayout {
  id: root

  // Whether it has the keys; a click asks for them through `tapped`.
  property bool active: true
  property bool busy: false
  property var key: ""
  property string glyph: Glyphs.prompt
  property alias text: area.text
  property alias placeholder: area.placeholder
  property alias maxLines: area.maxLines
  // Nothing to clear; an owner with more to clear than the text (a pasted image) says when.
  property bool empty: text === ""
  // A line over the text, in the same place: what its owner says about what was sent (an agent's answer), `noteGlyph` in the glyph's column; a click reaches `noteTapped`.
  property string note: ""
  property string noteGlyph: ""
  property string noteTone: "dim"

  signal keyPressed(var event)
  signal tapped
  signal cleared
  signal unfocused
  signal noteTapped

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

  // A row, lit under the pointer as anything clickable is; outset by its padding, so its glyph keeps the prompt's column.
  ListItem {
    Layout.fillWidth: true
    Layout.leftMargin: -Config.theme.itemPaddingX
    Layout.rightMargin: -Config.theme.itemPaddingX
    visible: root.note !== ""
    verticalPadding: Config.theme.itemPaddingY / 2
    onActivated: root.noteTapped()

    Item {
      implicitWidth: Metrics.line
      implicitHeight: Metrics.line

      Icon {
        anchors.centerIn: parent
        tone: root.noteTone
        glyph: root.noteGlyph
        size: Metrics.line
      }
    }

    Label {
      Layout.fillWidth: true
      tone: root.noteTone
      elide: Text.ElideRight
      maximumLineCount: 1
      text: root.note
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Config.theme.spacing

    // Its key and its glyph share one square, so the text holds still as it takes the keys.
    Item {
      Layout.alignment: Qt.AlignTop
      implicitWidth: Metrics.line
      implicitHeight: Metrics.line

      Spinner {
        anchors.centerIn: parent
        visible: root.busy
        tone: "dim"
        size: Metrics.line
      }

      KeyHint {
        anchors.centerIn: parent
        visible: !root.busy && !root.active && root.key !== ""
        key: root.key
        chars: MenuKeys.label(root.key).length
      }

      Icon {
        anchors.centerIn: parent
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
  }
}
