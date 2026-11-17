pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

// Icon, an optional title, text elided to fit and a detail on the right; with a title, the text is a value beside it, right-aligned.
RowLayout {
  id: root

  property string glyph
  property string image
  // A row's own label, which never changes; what it reports follows on the right.
  property string title
  property string text
  property string detail
  // Glyphs on the right before the detail (a mode, a submenu), drawn as icons the height of its text.
  property var detailGlyphs: []
  // The icon's, the title's and, without a title, the text's.
  property string tone: "normal"
  // What reports: the detail's, and with a title the text's too.
  property string valueTone: "dim"
  // Its value right after its title rather than on the right, for a row alone in reporting (an action in its level).
  property bool packed: false
  // A picture of the value beside it (0 to 1), the volume or brightness; below 0, none.
  property real meter: -1
  property string meterTone: "primary"
  // Its text struck through, for what is done.
  property bool struck: false
  readonly property bool titled: title !== ""

  spacing: Config.theme.spacing

  Icon {
    glyph: root.glyph
    source: root.image
    tone: root.tone
  }

  Label {
    visible: root.titled
    Layout.minimumWidth: implicitWidth
    // Without a value beside it, it pushes the detail to the right.
    Layout.fillWidth: !root.packed && root.text === ""
    tone: root.tone
    text: root.title
  }

  Label {
    visible: root.text !== ""
    Layout.fillWidth: !root.packed
    // Squeezed, text ends in an ellipsis, but a short value (80%, EN) stays whole.
    Layout.minimumWidth: Math.min(implicitWidth, 6 * Metrics.cell)
    horizontalAlignment: root.titled && !root.packed ? Text.AlignRight : Text.AlignLeft
    elide: Text.ElideRight
    font.strikeout: root.struck
    tone: root.titled ? root.valueTone : root.tone
    text: root.text
  }

  Repeater {
    model: root.detailGlyphs

    Icon {
      required property string modelData
      size: detailLabel.implicitHeight
      tone: "dim"
      glyph: modelData
    }
  }

  Label {
    id: detailLabel
    visible: root.detail !== ""
    Layout.minimumWidth: implicitWidth
    horizontalAlignment: Text.AlignRight
    tone: root.valueTone
    text: root.detail
  }

  // A neighbour, not part of the value: the full gap, half of it from the row.
  Meter {
    visible: root.meter >= 0
    Layout.leftMargin: Config.theme.spacing / 2
    Layout.preferredWidth: Config.theme.meterLength
    value: Math.max(0, root.meter)
    tone: root.meterTone
  }

  // Packed, what is left of the row stays empty after the value.
  Item {
    visible: root.packed
    Layout.fillWidth: true
  }
}
