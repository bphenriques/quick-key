import QtQuick
import qs

// Plain text typed in, in the theme font, with a dim `placeholder` while empty, growing to `maxLines`, then scrolling; keys reach `keyPressed` first, so the owner can take some.
Flickable {
  id: root

  property alias text: field.text
  property string placeholder: ""
  property int maxLines: 4
  property alias activeFocusOnPress: field.activeFocusOnPress

  signal keyPressed(var event)

  function clear() {
    field.clear();
  }

  function set(text) {
    field.text = text;
    field.cursorPosition = field.length;
  }

  implicitHeight: Math.min(field.contentHeight, maxLines * Metrics.line)
  contentHeight: field.contentHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  TextEdit {
    id: field
    width: root.width
    focus: true
    color: Tone.color("normal")
    Behavior on color {
      ColorAnimation {
        duration: Config.theme.animationDuration
      }
    }
    selectionColor: Tone.wash("primary", 2)
    selectedTextColor: Tone.color("normal")
    font.family: Config.theme.monospaceFont
    font.pointSize: Config.theme.fontSize
    textFormat: TextEdit.PlainText
    wrapMode: TextEdit.Wrap
    onCursorRectangleChanged: {
      if (root.contentY >= cursorRectangle.y) root.contentY = cursorRectangle.y;
      else if (root.contentY + root.height <= cursorRectangle.y + cursorRectangle.height) root.contentY = cursorRectangle.y + cursorRectangle.height - root.height;
    }
    Keys.onPressed: event => root.keyPressed(event)

    Label {
      visible: field.text === "" && root.placeholder !== ""
      tone: "dim"
      text: root.placeholder
    }
  }
}
