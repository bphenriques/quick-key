import QtQuick
import Quickshell
import qs

// An agent's answer as its Markdown says (ACP's text format): tables, lists, emphasis, code, quotes; a selection is copied, as a terminal does. Rendered by Markup.html, so nothing is fetched and no HTML runs; links are rows of their own.
TextEdit {
  id: root

  property string markdown
  property string tone: "normal"

  text: Markup.html(markdown)
  textFormat: TextEdit.RichText
  readOnly: true
  selectByMouse: true
  persistentSelection: true
  activeFocusOnPress: false
  wrapMode: TextEdit.Wrap
  color: Tone.color(tone)
  selectionColor: Tone.wash("primary", 2)
  selectedTextColor: Tone.color("normal")
  font.family: Config.theme.monospaceFont
  font.pointSize: Config.theme.fontSize
  onSelectedTextChanged: if (selectedText) Quickshell.clipboardText = selectedText
}
