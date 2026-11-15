import QtQuick
import Quickshell
import qs

// Plain text input in the theme font, coloured by `tone`; `copyOnSelect` copies a mouse selection, as a terminal does.
TextEdit {
  id: root

  property string tone: "normal"
  property string placeholder: ""
  property bool copyOnSelect: false

  color: Tone.color(tone)
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
  onSelectedTextChanged: if (copyOnSelect && selectedText) Quickshell.clipboardText = selectedText

  Label {
    visible: root.text === "" && root.placeholder !== ""
    tone: "dim"
    text: root.placeholder
  }
}
