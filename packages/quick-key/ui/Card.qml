import QtQuick
import QtQuick.Layouts
import qs

// A card that comes and goes on its own (a notification): its icon or a picture, its title and what it is from, a body of up to `lines`, a meter, actions on one side; a click activates it, a right click or its ✕ dismisses it. Its keys have their room at rest, so showing them moves nothing.
Surface {
  id: root

  property string glyph: ""
  // An app's icon in the glyph's place, at its size; a picture (album art, a screenshot) three lines tall instead.
  property string icon: ""
  property string image: ""
  property string title: ""
  // Who or what it is from, on the title's right.
  property string aside: ""
  property string body: ""
  property int lines: 2
  // From 0 to 1, with `meterText` beside it; below 0, none.
  property real meter: -1
  property string meterText: ""
  // Each { desc, key, run }, in order, on the side `actionSide` names.
  property var actions: []
  property string actionSide: "right"
  // In the actions' place while set (a reply's prompt, what was sent), so the card never grows; it has the keys.
  property Component footer: null
  // Alert for what must not be missed: its border, the glyph beside `aside` and the meter, so colour is not all that says so.
  property string tone: ""
  // What can no longer run (a card its sender closed), dim whole.
  property bool dimmed: false
  // Its digit in the gutter, the keys on its actions and `closeKey` by its ✕, shown while `keysShown`; an action's and the ✕'s only while `current`.
  property string key: ""
  property string closeKey: ""
  property bool keysShown: false
  property bool current: false
  readonly property bool hovered: mouse.containsMouse
  readonly property bool acting: keysShown && current
  readonly property string textTone: dimmed ? "dim" : "normal"

  signal activated
  signal dismissed

  implicitHeight: layout.implicitHeight + 2 * Config.theme.padding
  // Opaque: cards sit over working text, which would show through.
  color: Tone.surface(1)
  border.color: tone ? Tone.color(tone) : current ? Tone.color("primary") : Config.colors.border

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: root.current ? Tone.wash("primary") : root.hovered ? Tone.wash("normal") : "transparent"
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    hoverEnabled: true
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: event => event.button === Qt.RightButton ? root.dismissed() : root.activated()
  }

  RowLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Config.theme.padding
    spacing: Config.theme.spacing

    Label {
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: Metrics.cell
      tone: "primary"
      text: root.keysShown ? root.key : ""
    }

    Icon {
      Layout.alignment: Qt.AlignTop
      visible: root.image === ""
      glyph: root.glyph
      source: root.icon
      tone: root.textTone
    }

    // Square and three lines tall, cropped to fill, so the text starts in one place whatever the picture's shape.
    Image {
      Layout.alignment: Qt.AlignTop
      Layout.preferredWidth: 3 * Metrics.line
      Layout.preferredHeight: 3 * Metrics.line
      visible: root.image !== ""
      source: root.image
      sourceSize: Qt.size(6 * Metrics.line, 6 * Metrics.line)
      fillMode: Image.PreserveAspectCrop
      mipmap: true
    }

    ColumnLayout {
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: Config.theme.itemPaddingY

      RowLayout {
        Layout.fillWidth: true
        spacing: Config.theme.spacing

        Label {
          Layout.fillWidth: true
          elide: Text.ElideRight
          strong: true
          tone: root.textTone
          text: root.title
        }

        Icon {
          visible: root.tone !== ""
          size: Metrics.line
          tone: root.tone
          glyph: Glyphs.urgent
        }

        // A third of the width at most, so a long app name never takes the title's room.
        Label {
          Layout.maximumWidth: root.width / 3
          elide: Text.ElideRight
          tone: "dim"
          text: root.aside
        }
      }

      Label {
        Layout.fillWidth: true
        visible: root.body !== ""
        wrapMode: Text.Wrap
        maximumLineCount: root.lines
        elide: Text.ElideRight
        tone: root.textTone
        text: root.body
      }

      RowLayout {
        Layout.fillWidth: true
        visible: root.meter >= 0
        spacing: Config.theme.spacing

        Meter {
          Layout.fillWidth: true
          tone: root.tone || "primary"
          value: root.meter
        }

        Label {
          tone: root.tone || root.textTone
          text: root.meterText
        }
      }

      RowLayout {
        id: actionRow
        // An equal share each, labels shortened to fit, so every action and its key shows.
        readonly property real share: (width - root.actions.length * spacing) / Math.max(1, root.actions.length)
        Layout.fillWidth: true
        // The card's width, never its own: actions asking for theirs would widen the card past its edge.
        Layout.preferredWidth: 0
        visible: root.actions.length > 0 && root.footer === null
        spacing: 2 * Metrics.cell

        // Only on the open side: a hidden one takes no spacing, so the actions meet the edge.
        Item {
          visible: root.actionSide !== "left"
          Layout.fillWidth: true
        }

        Repeater {
          model: root.actions.length

          Item {
            id: action
            required property int index
            readonly property var entry: root.actions[index] ?? ({})
            implicitWidth: entryRow.implicitWidth
            implicitHeight: entryRow.implicitHeight

            Row {
              id: entryRow

              KeyCell {
                id: actionKey
                key: action.entry.key ?? ""
              }

              // Dim only on the cards the keys are not on, while summoned: dim says it cannot run now.
              Label {
                width: Math.min(implicitWidth, actionRow.share - actionKey.implicitWidth)
                elide: Text.ElideRight
                tone: hover.containsMouse ? "primary" : root.keysShown && !root.current ? "dim" : root.textTone
                text: action.entry.desc ?? ""
              }
            }

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              onClicked: if (action.entry.run) action.entry.run()
            }
          }
        }

        Item {
          visible: root.actionSide === "left"
          Layout.fillWidth: true
        }
      }

      Loader {
        Layout.fillWidth: true
        active: root.footer !== null
        visible: active
        focus: active
        sourceComponent: root.footer
      }
    }

    // Its ✕ and its key in a column of their own, mirroring the digit's, so the text ends on one edge.
    Row {
      Layout.alignment: Qt.AlignTop

      KeyCell {
        key: root.closeKey
      }

      Item {
        implicitWidth: Metrics.line
        implicitHeight: Metrics.line

        Icon {
          anchors.centerIn: parent
          visible: root.hovered || root.acting
          size: Metrics.line
          tone: close.containsMouse ? "primary" : "dim"
          glyph: Glyphs.close
        }

        MouseArea {
          id: close
          anchors.fill: parent
          hoverEnabled: true
          onClicked: root.dismissed()
        }
      }
    }
  }

  // A key and a space after it, its room kept while hidden.
  component KeyCell: Item {
    property string key
    implicitWidth: key ? hint.implicitWidth + Metrics.cell : 0
    implicitHeight: hint.implicitHeight

    KeyHint {
      id: hint
      visible: root.acting
      key: parent.key
      chars: MenuKeys.label(parent.key).length
    }
  }
}
