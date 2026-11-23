pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.ui

// One turn of a conversation: the question a bubble on the right, the answer on the left in Markdown; with `lines` it is compact, `overflows` saying what it cannot hold.
ColumnLayout {
  id: root

  property string question
  // Markdown, as ACP sends text; plain when compact.
  property string text
  property string phase: "done"
  property string kind: ""
  property string activity
  // The text is a table's rows: kept whole, so its columns line up.
  property bool table: false
  property int lines: 0
  property bool copyable: false
  // What you answered on the way (an approval), dim over the answer.
  property var steps: []
  // Set from what holds the conversation, never from the exchange's own width.
  property real maximumWidth: Infinity

  readonly property bool compact: lines > 0
  readonly property bool overflows: compact && (kind === "permission" || table || brief.width > 0 && brief.truncated)
  // What Return does next, for the prompt under it.
  readonly property string next: Words.next(phase, kind)
  // The selection to show again (Markdown.kept).
  property alias kept: answer.kept
  readonly property string tone: phase === "error" ? "alert" : kind === "permission" ? "warning" : phase === "idle" ? "dim" : ""

  signal selected(var selection)

  spacing: Config.theme.spacing / 2

  Bubble {
    mine: true
    // Its text is back in the prompt, to send again.
    faded: root.phase === "error"
    maximumWidth: root.maximumWidth

    Label {
      id: asked
      Layout.fillWidth: true
      color: Config.colors.bubbleText
      // Compact, one line unwrapped: a wrapped line cut short reports the width it was cut to, and the bubble would shrink to it.
      wrapMode: root.compact ? Text.NoWrap : Text.Wrap
      elide: Text.ElideRight
      // Its line breaks as spaces, compact: unwrapped text still breaks at them, and Qt elides only a single line.
      text: root.compact ? root.question.replace(/\s*\n\s*/g, " ") : root.question
    }
  }

  Repeater {
    model: root.compact ? [] : root.steps

    Label {
      required property string modelData
      Layout.fillWidth: true
      tone: "dim"
      wrapMode: Text.Wrap
      text: modelData
    }
  }

  RowLayout {
    Layout.fillWidth: true
    spacing: Config.theme.spacing / 2

    Bubble {
      Layout.alignment: Qt.AlignTop | Qt.AlignLeft
      maximumWidth: root.maximumWidth
      // Compact, its answer is cut at `lines`; the bubble is plain, so its width shows nowhere.
      full: root.compact
      clip: true

      RowLayout {
        visible: root.phase === "working" && root.text === ""
        spacing: Config.theme.spacing

        Spinner {
          tone: "primary"
          size: Metrics.line
        }

        Label {
          tone: "dim"
          text: root.activity || "Thinking"
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: root.phase !== "working" || root.text !== ""
        spacing: Config.theme.spacing

        Icon {
          Layout.alignment: Qt.AlignTop
          visible: root.phase === "error"
          tone: "alert"
          glyph: Glyphs.failed
          size: Metrics.line
        }

        // Cut at `lines`, which is how `overflows` knows.
        Label {
          id: brief
          Layout.fillWidth: true
          visible: root.compact
          tone: root.tone || "normal"
          wrapMode: root.table ? Text.NoWrap : Text.Wrap
          maximumLineCount: Math.max(1, root.lines)
          elide: Text.ElideRight
          // Hidden, a view still lays its text out: each takes the answer only while it shows.
          text: root.compact ? Markup.plain(root.text) : ""
        }

        Markdown {
          id: answer
          Layout.fillWidth: true
          onSelected: selection => root.selected(selection)
          visible: !root.compact
          tone: root.tone || "normal"
          markdown: root.compact ? "" : root.text
        }
      }
    }

    // At its end, so it reads as the whole answer's; a selection copies its part.
    ListItem {
      Layout.alignment: Qt.AlignBottom
      visible: root.copyable && root.phase === "done"
      onActivated: Quickshell.clipboardText = root.text

      Icon {
        tone: "dim"
        glyph: Glyphs.copy
        size: Metrics.line
      }
    }

    // Still streaming in, where the copy button shows once it is done; the prompt's glyph stays, as typing ahead is free.
    Spinner {
      Layout.alignment: Qt.AlignBottom
      Layout.leftMargin: Metrics.itemPaddingX
      Layout.bottomMargin: Metrics.itemPaddingY
      visible: root.phase === "working" && root.text !== ""
      tone: "primary"
      size: Metrics.line
    }

    // Fills the row, so the exchange is as wide as what holds it and the question sits on its right (a layout grows no wider than its children).
    Item {
      Layout.fillWidth: true
    }
  }
}
