pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// An agent's answer, rendered by Markup.html a piece at a time so a stream redraws only its last; a selection is copied, as a terminal does.
ColumnLayout {
  id: root

  property string markdown
  property string tone: "normal"
  // A selection to show again as its piece is made, as `selected` reported it: { piece, start, end }.
  property var kept: null
  // The piece selected in last; a selection in another clears it, so one shows at a time.
  property int current: -1
  // Characters a piece gathers before the next starts: what a streaming piece costs to redraw, against how many an answer arriving whole is drawn as.
  readonly property int pieceSize: 1000

  // A selection made or cleared, { piece, start, end } or null, for whoever keeps it while its piece is gone.
  signal selected(var selection)

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
      readonly property bool others: root.current !== index
      // Showing a kept selection again, which is not copied again, so it never overwrites what was copied since.
      property bool restoring: false

      Layout.fillWidth: true
      text: Markup.html(source)
      textFormat: TextEdit.RichText
      readOnly: true
      selectByMouse: true
      persistentSelection: true
      activeFocusOnPress: false
      // Unwrapped until a layout gives it a width: at none it would wrap every character, and a list would size itself by that height.
      wrapMode: width > 0 ? TextEdit.Wrap : TextEdit.NoWrap
      // Snaps, unlike a Label: easing a rich text's colour redraws the whole answer every frame.
      color: Tone.color(root.tone)
      selectionColor: Tone.wash("primary", 2)
      selectedTextColor: Tone.color("normal")
      font.family: Config.theme.monospaceFont
      font.pointSize: Config.theme.fontSize
      onOthersChanged: if (others) deselect()
      Component.onCompleted: {
        const kept = root.kept;
        if (!kept || kept.piece !== index || kept.end > length) return;
        root.current = index;
        restoring = true;
        select(kept.start, kept.end);
        restoring = false;
      }
      onSelectedTextChanged: {
        if (!selectedText) {
          if (root.current === index) root.selected(null);
          return;
        }
        root.current = index;
        if (restoring) return;
        Quickshell.clipboardText = selectedText;
        root.selected({ piece: index, start: selectionStart, end: selectionEnd });
      }
    }
  }
}
