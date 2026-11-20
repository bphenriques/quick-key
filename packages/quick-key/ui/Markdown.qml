pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// An agent's answer as its Markdown says (ACP's text format): tables, lists, emphasis, code, quotes; a selection is copied, as a terminal does. Rendered by Markup.html, so nothing is fetched and no HTML runs, a piece at a time, so a stream redraws only its last; links are rows of their own.
ColumnLayout {
  id: root

  property string markdown
  property string tone: "normal"
  // The piece selected in last; a selection in another clears it, so one shows at a time.
  property int selected: -1
  // Characters a piece gathers before the next starts: what a streaming piece costs to redraw, against how many an answer arriving whole is drawn as.
  readonly property int pieceSize: 1000

  spacing: Config.theme.spacing

  onMarkdownChanged: update()
  Component.onCompleted: update()

  // Its pieces kept in step with the text, so a piece the stream left as it was is neither told nor rendered again.
  function update() {
    const parts = Markup.split(markdown, pieceSize);
    for (let i = 0; i < parts.length; i++) {
      if (i >= pieces.count) pieces.append({ source: parts[i] });
      else if (pieces.get(i).source !== parts[i]) pieces.setProperty(i, "source", parts[i]);
    }
    if (pieces.count > parts.length) pieces.remove(parts.length, pieces.count - parts.length);
  }

  ListModel {
    id: pieces
  }

  Repeater {
    model: pieces

    TextEdit {
      required property int index
      required property string source
      readonly property bool others: root.selected !== index

      Layout.fillWidth: true
      text: Markup.html(source)
      textFormat: TextEdit.RichText
      readOnly: true
      selectByMouse: true
      persistentSelection: true
      activeFocusOnPress: false
      wrapMode: TextEdit.Wrap
      color: Tone.color(root.tone)
      selectionColor: Tone.wash("primary", 2)
      selectedTextColor: Tone.color("normal")
      font.family: Config.theme.monospaceFont
      font.pointSize: Config.theme.fontSize
      onOthersChanged: if (others) deselect()
      onSelectedTextChanged: {
        if (!selectedText) return;
        root.selected = index;
        Quickshell.clipboardText = selectedText;
      }
    }
  }
}
