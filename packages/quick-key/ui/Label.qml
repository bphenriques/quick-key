import QtQuick
import qs

// Text in the theme font, coloured by `tone` (see Tone); `strong` for the one to find first (a key, the clock, a heading).
Text {
  property string tone: "normal"
  property bool strong: false

  color: Tone.color(tone)
  Behavior on color {
    ColorAnimation {
      duration: Config.theme.animationDuration
    }
  }
  font.family: Config.theme.monospaceFont
  font.pointSize: Config.theme.fontSize
  font.bold: strong
  // Never rich text: stream titles can carry whole XML documents (Bauer Media radio does).
  textFormat: Text.PlainText
}
