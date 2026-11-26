pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

// Icon, an optional title, text elided to fit and a detail on the right; with a title, the text is a value beside it, right-aligned.
// Squeezed, the title keeps its width and the value and the detail shorten to `least`, so nothing leaves the card: each label fills, as a layout fixes one that does not fill at its full width.
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

  // The least a value keeps when squeezed: all of a short one (80%, EN), else `chars` characters.
  function least(label, chars) {
    const whole = Math.ceil(label.implicitWidth);
    return whole <= 6 * Metrics.cell ? whole : chars * Metrics.cell;
  }
  // A picture of the value beside it (0 to 1), the volume or brightness; below 0, none.
  property real meter: -1
  property string meterTone: "primary"
  // A colour that is data (a task's list), as a dot after the detail; unset, none.
  property string swatch: ""
  property bool struck: false
  // Its text bold, the one to find first (the clock).
  property bool strong: false
  // Still being made: a spinner in place of its icon.
  property bool busy: false
  // Its icon in the square, off where it stands in no column (see Icon).
  property bool squareIcon: true
  property bool labelShown: true
  readonly property bool titled: title !== ""
  // Its value shortened to fit, so a bar item tips it whole.
  readonly property bool cut: textLabel.truncated || detailLabel.truncated

  spacing: Config.theme.spacing

  Icon {
    busy: root.busy
    square: root.squareIcon
    glyph: root.glyph
    source: root.image
    tone: root.tone
  }

  Label {
    id: titleLabel
    visible: root.titled && root.labelShown
    // With no value beside it, as wide as the row, pushing the detail to the right.
    Layout.fillWidth: true
    // Rounded up: a layout rounds sizes down, and a fraction short would elide the label.
    Layout.maximumWidth: root.packed || root.text !== "" ? Math.ceil(implicitWidth) : Number.POSITIVE_INFINITY
    Layout.minimumWidth: Math.ceil(implicitWidth)
    elide: Text.ElideRight
    tone: root.tone
    text: root.title
  }

  Label {
    id: textLabel
    visible: root.text !== "" && (root.titled || root.labelShown)
    // Packed, as wide as itself at most, still shortening when squeezed.
    Layout.fillWidth: true
    Layout.maximumWidth: root.packed ? Math.ceil(implicitWidth) : Number.POSITIVE_INFINITY
    // Squeezed, text ends in an ellipsis, but a short value (80%, EN) stays whole: only a longer one gives way.
    Layout.minimumWidth: root.least(textLabel, 2)
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
    Layout.fillWidth: true
    Layout.maximumWidth: Math.ceil(implicitWidth)
    Layout.minimumWidth: root.least(detailLabel, 4)
    elide: Text.ElideRight
    horizontalAlignment: Text.AlignRight
    tone: root.valueTone
    text: root.detail
  }

  Swatch {
    visible: root.swatch !== ""
    size: Metrics.cell
    fill: root.swatch || "transparent"
    tone: root.tone
  }

  // A neighbour, not part of the value: the full gap, half of it from the row.
  Meter {
    visible: root.meter >= 0
    Layout.leftMargin: Config.theme.spacing / 2
    Layout.preferredWidth: Metrics.meterLength
    value: Math.max(0, root.meter)
    tone: root.meterTone
  }

  // Packed, what is left of the row stays empty after the value.
  Item {
    visible: root.packed
    Layout.fillWidth: true
  }
}
