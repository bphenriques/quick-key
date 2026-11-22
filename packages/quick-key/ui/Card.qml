import QtQuick
import QtQuick.Layouts
import qs

// A card that comes and goes on its own (a notification): its icon or a picture three lines tall, title and what it is from, a body of up to `lines`, a meter, actions on one side; a click activates it, a right click or its ✕ dismisses it. Its keys have their room at rest, so showing them moves nothing.
Surface {
  id: root

  property string glyph: ""
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
  // Alert for what must not be missed: its border, icon, title and meter, and a glyph beside `aside`.
  property string tone: ""
  // Its digit in the gutter, the keys on its actions and `closeKey` by its ✕, shown while `keysShown`; an action's and the ✕'s only while `current`.
  property string key: ""
  property string closeKey: ""
  property bool keysShown: false
  property bool current: false
  readonly property bool hovered: mouse.containsMouse
  readonly property bool acting: keysShown && current

  signal activated
  signal dismissed

  implicitHeight: layout.implicitHeight + 2 * Config.theme.padding
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
      tone: root.tone || "normal"
    }

    // Three lines tall and as wide as its shape, up to twice that, so album art and screenshots read.
    Image {
      Layout.alignment: Qt.AlignTop
      Layout.preferredHeight: 3 * Metrics.line
      Layout.preferredWidth: implicitHeight > 0 ? Math.min(2, implicitWidth / implicitHeight) * Layout.preferredHeight : Layout.preferredHeight
      visible: root.image !== ""
      source: root.image
      mipmap: true
      fillMode: Image.PreserveAspectFit
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
          tone: root.tone || "normal"
          text: root.title
        }

        Icon {
          visible: root.tone !== ""
          size: Metrics.line
          tone: root.tone
          glyph: Glyphs.urgent
        }

        Label {
          tone: root.tone ? root.tone : "dim"
          text: root.aside
        }

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

      Label {
        Layout.fillWidth: true
        visible: root.body !== ""
        wrapMode: Text.Wrap
        maximumLineCount: root.lines
        elide: Text.ElideRight
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
          tone: root.tone || "normal"
          text: root.meterText
        }
      }

      RowLayout {
        Layout.fillWidth: true
        visible: root.actions.length > 0
        clip: true
        spacing: 2 * Metrics.cell

        Item {
          Layout.fillWidth: root.actionSide !== "left"
        }

        Repeater {
          model: root.actions.length

          Item {
            id: action
            required property int index
            readonly property var entry: root.actions[index] ?? ({})
            implicitWidth: actionRow.implicitWidth
            implicitHeight: actionRow.implicitHeight

            Row {
              id: actionRow

              KeyCell {
                key: action.entry.key ?? ""
              }

              Label {
                tone: hover.containsMouse ? "primary" : root.current ? "normal" : "dim"
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
          Layout.fillWidth: root.actionSide === "left"
        }
      }
    }
  }

  // A key and a space after it, its room kept while hidden.
  component KeyCell: Item {
    property string key
    implicitWidth: key ? hint.implicitWidth + Metrics.cell : 0
    implicitHeight: hint.implicitHeight

    Label {
      id: hint
      visible: root.acting
      tone: "primary"
      text: MenuKeys.label(parent.key)
    }
  }
}
