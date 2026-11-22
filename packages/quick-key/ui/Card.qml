import QtQuick
import QtQuick.Layouts
import qs

// A card that comes and goes on its own (a notification): its icon, title and what it is from, a body of up to `lines`, a meter, actions on one side; a click activates it, a right click or its ✕ dismisses it.
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
  // Each { desc, run }, in order, on the side `actionSide` names.
  property var actions: []
  property string actionSide: "right"
  // Alert for what must not be missed: its border, icon, title and meter, and a glyph beside `aside`.
  property string tone: ""
  readonly property bool hovered: mouse.containsMouse

  signal activated
  signal dismissed

  implicitHeight: layout.implicitHeight + 2 * Config.theme.padding
  border.color: tone ? Tone.color(tone) : Config.colors.border

  Rectangle {
    anchors.fill: parent
    radius: parent.radius
    color: root.hovered ? Tone.wash("normal") : "transparent"
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

    Icon {
      Layout.alignment: Qt.AlignTop
      glyph: root.glyph
      source: root.image
      tone: root.tone || "normal"
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

        // Its room kept while hidden, so the title never moves under the pointer.
        Item {
          implicitWidth: Metrics.line
          implicitHeight: Metrics.line

          Icon {
            anchors.centerIn: parent
            visible: root.hovered
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
        spacing: 2 * Metrics.cell

        Item {
          Layout.fillWidth: root.actionSide !== "left"
        }

        Repeater {
          model: root.actions.length

          Label {
            id: action
            required property int index
            tone: hover.containsMouse ? "primary" : "dim"
            text: root.actions[index]?.desc ?? ""

            MouseArea {
              id: hover
              anchors.fill: parent
              hoverEnabled: true
              onClicked: root.actions[action.index]?.run()
            }
          }
        }

        Item {
          Layout.fillWidth: root.actionSide === "left"
        }
      }
    }
  }
}
