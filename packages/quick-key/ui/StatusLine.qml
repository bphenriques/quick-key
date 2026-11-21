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
  // Glyphs on the right before the detail (a mode, a submenu, a late task's alarm), drawn as icons the height of its text, in the detail's tone.
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
  // Its text bold, the one to find first (the clock).
  property bool strong: false
  // Still being made: a spinner in place of its icon.
  property bool busy: false
  // Its label (the title, else the text) shown.
  property bool labelShown: true
  readonly property bool titled: title !== ""

  spacing: Config.theme.spacing

  Icon {
    visible: !root.busy && (glyph !== "" || source !== "")
    glyph: root.glyph
    source: root.image
    tone: root.tone
  }

  Spinner {
    visible: root.busy
    tone: root.tone
  }

  Label {
    id: titleLabel
    visible: root.titled && root.labelShown
    Layout.minimumWidth: implicitWidth
    // Without a value beside it, it pushes the detail to the right.
    Layout.fillWidth: !root.packed && root.text === ""
    tone: root.tone
    text: root.title
  }

  Label {
    id: textLabel
    visible: root.text !== "" && (root.titled || root.labelShown)
    Layout.fillWidth: !root.packed
    // Squeezed, text ends in an ellipsis, but a short value (80%, EN) stays whole.
    Layout.minimumWidth: Math.min(implicitWidth, 6 * Metrics.cell)
    horizontalAlignment: root.titled && !root.packed ? Text.AlignRight : Text.AlignLeft
    elide: Text.ElideRight
    font.strikeout: root.struck
    strong: root.strong
    tone: root.titled ? root.valueTone : root.tone
    text: root.text
  }

  Repeater {
    model: root.detailGlyphs

    Icon {
      required property string modelData
      size: detailLabel.implicitHeight
      tone: root.valueTone
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
