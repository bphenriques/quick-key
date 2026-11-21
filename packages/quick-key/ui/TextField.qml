import QtQuick
import qs

// Plain text input in the theme font, coloured by `tone`.
TextEdit {
  id: root

  property string tone: "normal"
  property string placeholder: ""

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

  Label {
    visible: root.text === "" && root.placeholder !== ""
    tone: "dim"
    text: root.placeholder
  }
}
