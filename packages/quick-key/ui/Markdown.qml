import QtQuick
import Quickshell
import qs

// An agent's answer as its Markdown says (ACP's text format): tables, lists, emphasis, code; a selection is copied, as a terminal does. Rendered safe (Markup.safe): an image or a link shows its text (links are rows of their own, and Qt draws them in a blue no theme reaches), so nothing is fetched and no HTML runs.
TextEdit {
  id: root

  property string markdown
  property string tone: "normal"

  text: Markup.safe(markdown)
  textFormat: TextEdit.MarkdownText
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
