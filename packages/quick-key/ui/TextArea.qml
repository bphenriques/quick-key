import QtQuick

// A TextField growing to `maxLines`, then scrolling; keys reach `keyPressed` first, so the owner can take some.
Flickable {
  id: root

  property alias text: field.text
  property alias placeholder: field.placeholder
  property int maxLines: 4

  signal keyPressed(var event)

  function clear() {
    field.clear();
  }

  function paste() {
    field.paste();
  }

  // Replaces the text, the cursor at its end.
  function set(text) {
    field.text = text;
    field.cursorPosition = field.length;
  }

  implicitHeight: Math.min(field.contentHeight, maxLines * Metrics.line)
  contentHeight: field.contentHeight
  clip: true
  boundsBehavior: Flickable.StopAtBounds

  TextField {
    id: field
    width: root.width
    focus: true
    onCursorRectangleChanged: {
      if (root.contentY >= cursorRectangle.y) root.contentY = cursorRectangle.y;
      else if (root.contentY + root.height <= cursorRectangle.y + cursorRectangle.height) root.contentY = cursorRectangle.y + cursorRectangle.height - root.height;
    }
    Keys.onPressed: event => root.keyPressed(event)
  }
}
