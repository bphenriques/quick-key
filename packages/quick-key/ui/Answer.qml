pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

// What a plugin said about what was sent, over the prompt in its island: the question, then `lines` lines reserved for the answer (text wrapping, a table's rows unwrapped, or options as digits), the last saying how to continue when the rest does not fit. Lit while `current` (Tab); a click, or Return while current, reaches `activated`.
ListItem {
  id: root

  property string question
  property string text
  // alert for a failure, warning for something waiting on you (an approval).
  property string tone: ""
  property string glyph
  property bool table: false
  property var options: []
  // Escape sets the options aside: they stay as text, and the digits type again.
  property bool aside: false
  property int lines: 3
  // The prompt's key column, so the text lines up with it.
  property real slot: Metrics.line

  // Whether a digit picks an option: all of them show, as keys.
  readonly property bool picking: options.length > 0 && !aside && choices.fits
  readonly property var rows: table ? text.split("\n") : []
  readonly property bool rowsCut: rows.length > lines
  readonly property bool textCut: !table && options.length === 0 && probe.truncated
  // The last line's say: how to continue, or what to press; [] when everything fits.
  readonly property var next: tone === "alert" ? [{ key: "Return", what: "retry" }]
    : tone === "warning" ? [{ key: "Tab" }, { key: "Return", what: "answer" }]
    : picking ? [{ key: "Escape", what: "aside" }, { key: "Tab" }, { key: "Return", what: "open" }]
    : options.length > 0 ? [{ key: "Tab" }, { key: "Return", what: "choose" }]
    : rowsCut || textCut ? [{ key: "Tab" }, { key: "Return", what: rowsCut ? "open" : "read the rest" }] : []
  readonly property string summary: picking ? "a digit picks, or type ·" : options.length > 0 ? options.length + " options ·"
    : rowsCut ? "+" + (rows.length - lines + 1) + " rows ·" : textCut ? "… " : ""
  // Lines the answer's own text may take, the rest going to the options and to the last line.
  readonly property int textLines: lines - (options.length > 0 && choices.fits ? 1 : 0) - (next.length > 0 ? 1 : 0)

  Layout.fillWidth: true
  // Outset by its padding, so its glyph keeps the prompt's column.
  Layout.leftMargin: -Config.theme.itemPaddingX
  Layout.rightMargin: -Config.theme.itemPaddingX
  verticalPadding: 0

  component Gutter: Item {
    property alias glyph: icon.glyph
    property alias tone: icon.tone
    Layout.alignment: Qt.AlignTop
    implicitWidth: root.slot
    implicitHeight: Metrics.line

    Icon {
      id: icon
      anchors.centerIn: parent
      size: Metrics.line
    }
  }

  ColumnLayout {
    Layout.fillWidth: true
    spacing: 0

    RowLayout {
      Layout.fillWidth: true
      spacing: Config.theme.spacing

      Gutter {
        glyph: Glyphs.prompt
        tone: "dim"
      }

      Label {
        Layout.fillWidth: true
        tone: "dim"
        elide: Text.ElideRight
        text: root.question
      }
    }

    // The reserved lines: the island holds still whatever the answer is.
    RowLayout {
      Layout.fillWidth: true
      Layout.preferredHeight: root.lines * Metrics.line
      spacing: Config.theme.spacing

      Gutter {
        glyph: root.tone === "alert" ? Glyphs.failed : root.glyph
        tone: root.tone || "dim"
      }

      ColumnLayout {
        Layout.fillWidth: true
        Layout.alignment: Qt.AlignTop
        spacing: 0

        // How many lines the whole text takes, to know whether it is cut.
        Label {
          id: probe
          Layout.fillWidth: true
          Layout.maximumHeight: 0
          visible: false
          wrapMode: Text.Wrap
          maximumLineCount: root.lines - (root.tone ? 1 : 0)
          text: root.text
        }

        Label {
          Layout.fillWidth: true
          visible: !root.table
          tone: root.tone || "normal"
          wrapMode: Text.Wrap
          elide: Text.ElideRight
          maximumLineCount: Math.max(1, root.textLines)
          text: root.text
        }

        Repeater {
          model: root.table ? root.rows.slice(0, root.rowsCut ? root.lines - 1 : root.lines) : []

          Label {
            required property string modelData
            Layout.fillWidth: true
            elide: Text.ElideRight
            text: modelData
          }
        }

        // The options on one line, as keys while a digit picks them.
        RowLayout {
          id: choices
          readonly property bool fits: root.options.length <= 9 && implicitWidth <= root.width - root.slot - 2 * Config.theme.itemPaddingX
          Layout.fillWidth: true
          visible: root.options.length > 0 && fits
          spacing: 2 * Config.theme.spacing

          Repeater {
            model: root.options

            RowLayout {
              id: option
              required property int index
              required property string modelData
              spacing: Config.theme.spacing

              KeyHint {
                visible: root.picking
                key: String(option.index + 1)
              }

              Label {
                tone: root.picking ? "normal" : "dim"
                text: option.modelData
              }
            }
          }
        }

        RowLayout {
          visible: root.next.length > 0
          spacing: Config.theme.spacing

          Label {
            visible: root.summary !== ""
            tone: "dim"
            text: root.summary
          }

          Repeater {
            model: root.next

            RowLayout {
              id: step
              required property var modelData
              spacing: Config.theme.spacing / 2

              KeyHint {
                key: step.modelData.key
                chars: MenuKeys.label(step.modelData.key).length
              }

              Label {
                visible: !!step.modelData.what
                tone: "dim"
                text: step.modelData.what ?? ""
              }
            }
          }
        }
      }
    }
  }
}
