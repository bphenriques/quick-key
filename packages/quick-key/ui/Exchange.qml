pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs

// One turn of a conversation as bubbles, the question right and the answer left, drawn by its `phase` (working, answered, choosing, waiting, failed, stopped); with `lines` it is compact, `overflows` saying what it cannot hold.
ColumnLayout {
  id: root

  property string question
  // The answer just before the question, dim over it while the question waits for its own: what is being answered.
  property string context
  // A picture sent with the question, as a file path.
  property string image
  property string text
  property string phase: "answered"
  property string activity
  property var options: []
  // The text is a table's rows: kept whole, so its columns line up.
  property bool table: false
  property bool picking: false
  property int lines: 0
  property bool copyable: false
  // How wide a bubble may grow; set from what holds the conversation, never from the exchange's own width.
  property real maximumWidth: Infinity

  readonly property bool compact: lines > 0
  readonly property bool fits: options.length <= 9 && choices.implicitWidth <= maximumWidth - 2 * Config.theme.itemPaddingX
  readonly property bool overflows: compact && (phase === "waiting" || brief.width > 0 && brief.truncated || (options.length > 0 && !fits))
  readonly property string tone: phase === "failed" ? "alert" : phase === "waiting" ? "warning" : phase === "stopped" ? "dim" : ""

  signal picked(int index)

  spacing: Config.theme.spacing / 2

  Bubble {
    visible: root.context !== ""
    maximumWidth: root.maximumWidth

    Label {
      Layout.fillWidth: true
      tone: "dim"
      wrapMode: Text.Wrap
      maximumLineCount: root.compact ? root.lines : 1000
      elide: Text.ElideRight
      text: root.context
    }
  }

  Bubble {
    mine: true
    maximumWidth: root.maximumWidth

    Image {
      visible: root.image !== ""
      source: root.image ? "file://" + root.image : ""
      fillMode: Image.PreserveAspectFit
      sourceSize.height: Metrics.line * 4
      Layout.preferredHeight: Metrics.line * 4
      Layout.preferredWidth: implicitHeight > 0 ? Layout.preferredHeight * implicitWidth / implicitHeight : 0
    }

    Label {
      id: asked
      Layout.fillWidth: true
      // Its measured width: an elided line reports the width it was cut to, so a longer question would keep a shorter one's.
      Layout.preferredWidth: Math.ceil(Metrics.width(root.question))
      wrapMode: Text.Wrap
      maximumLineCount: root.compact ? 1 : 1000
      elide: Text.ElideRight
      text: root.question
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Config.theme.spacing / 2

    Bubble {
      Layout.alignment: Qt.AlignTop | Qt.AlignLeft
      tone: root.tone
      maximumWidth: root.maximumWidth
      clip: true

      RowLayout {
        visible: root.phase === "working"
        spacing: Config.theme.spacing

        Spinner {
          tone: "dim"
          size: Metrics.line
        }

        Label {
          visible: root.activity !== ""
          tone: "dim"
          text: root.activity
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: root.phase !== "working"
        spacing: Config.theme.spacing

        Icon {
          Layout.alignment: Qt.AlignTop
          visible: root.phase === "failed"
          tone: "alert"
          glyph: Glyphs.failed
          size: Metrics.line
        }

        // Compact: cut at `lines`, which is how `overflows` knows.
        Label {
          id: brief
          Layout.fillWidth: true
          visible: root.compact
          tone: root.tone || "normal"
          wrapMode: root.table ? Text.NoWrap : Text.Wrap
          maximumLineCount: Math.max(1, root.lines)
          elide: Text.ElideRight
          text: root.text
        }

        TextField {
          Layout.fillWidth: true
          visible: !root.compact
          tone: root.tone || "normal"
          wrapMode: root.table ? TextEdit.NoWrap : TextEdit.Wrap
          text: root.text
          readOnly: true
          selectByMouse: true
          persistentSelection: true
          activeFocusOnPress: false
          copyOnSelect: true
        }
      }

      // Compact, the options on one line, as keys while a digit picks them.
      RowLayout {
        id: choices
        visible: root.compact && root.options.length > 0 && root.fits
        spacing: 2 * Config.theme.spacing

        Repeater {
          model: root.options

          RowLayout {
            id: chip
            required property int index
            required property string modelData
            spacing: Config.theme.spacing

            KeyHint {
              visible: root.picking
              key: String(chip.index + 1)
            }

            Label {
              tone: root.picking ? "normal" : "dim"
              text: chip.modelData
            }
          }
        }
      }
    }

    // Copies the whole answer; a selection copies its part.
    ListItem {
      Layout.alignment: Qt.AlignTop
      visible: root.copyable && (root.phase === "answered" || root.phase === "choosing")
      onActivated: Quickshell.clipboardText = root.text

      Icon {
        tone: "dim"
        glyph: Glyphs.copy
        size: Metrics.line
      }
    }

    // Fills the row, so the exchange is as wide as what holds it and the question sits on its right (a layout grows no wider than its children).
    Item {
      Layout.fillWidth: true
    }
  }

  // Not compact, the options as rows, a digit (`picking`) or a click choosing one.
  Repeater {
    model: root.compact ? [] : root.options

    ListItem {
      id: option
      required property int index
      required property string modelData
      Layout.fillWidth: true
      onActivated: root.picked(option.index)

      KeyHint {
        visible: root.picking
        key: String(option.index + 1)
      }

      Label {
        Layout.fillWidth: true
        text: option.modelData
      }
    }
  }
}
