pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui

// The selected day's month in the clock's locale: today lit, the selected day highlighted, a dot per event colour.
Item {
  id: root

  required property var selected
  // Its month and year, over the grid.
  property string title

  signal stepped(int months)
  signal picked(var day)

  readonly property int firstDay: Clock.firstDayOfWeek
  readonly property real dotSize: Config.theme.fontSize / 2
  readonly property real dotGap: Config.theme.spacing / 4
  // More would spill into the next day.
  readonly property int maxDots: 4
  // Tighter than a menu row: six weeks of them stack up.
  readonly property real cellPadding: Config.theme.itemPaddingY / 2
  // By month, so a day picked within it rebuilds nothing.
  readonly property int year: selected.getFullYear()
  readonly property int month: selected.getMonth()
  // Six weeks from the one holding the 1st, so the grid never changes height.
  readonly property var days: {
    const first = new Date(year, month, 1);
    const lead = (first.getDay() - firstDay + 7) % 7;
    return Array.from({ length: 42 }, (_, i) => new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
  }

  implicitHeight: titleLabel.implicitHeight + Config.theme.itemPaddingY + grid.implicitHeight

  Label {
    id: titleLabel
    x: Config.theme.itemPaddingX
    font.bold: true
    text: root.title
  }

  GridLayout {
    id: grid
    anchors.top: titleLabel.bottom
    anchors.topMargin: Config.theme.itemPaddingY
    anchors.left: parent.left
    anchors.right: parent.right
    columns: 7
    columnSpacing: 0
    rowSpacing: 0

    Repeater {
      model: 7

      Label {
        required property int index
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.bottomMargin: Config.theme.itemPaddingY
        horizontalAlignment: Text.AlignHCenter
        tone: "dim"
        // Some locales' short names are whole words (pt: segunda), too wide for a column.
        text: Clock.locale.dayName((root.firstDay + index) % 7, Locale.ShortFormat).slice(0, 3)
      }
    }

    Repeater {
      model: root.days

      ListItem {
        id: cell
        required property date modelData
        readonly property bool isToday: modelData.toDateString() === Clock.date.toDateString()
        readonly property bool inMonth: modelData.getMonth() === root.month

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        verticalPadding: root.cellPadding
        current: modelData.toDateString() === root.selected.toDateString()
        onActivated: root.picked(cell.modelData)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: root.dotGap

          Label {
            Layout.alignment: Qt.AlignHCenter
            tone: cell.isToday ? "primary" : cell.inMonth ? "normal" : "dim"
            font.bold: cell.isToday
            text: cell.modelData.getDate()
          }

          // Room for the dots whether a day has events or not, so the grid holds still.
          Row {
            visible: Calendar.enabled
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.dotSize
            spacing: root.dotGap

            Repeater {
              model: Calendar.enabled ? Calendar.colorsOn(cell.modelData).slice(0, root.maxDots) : []

              Swatch {
                required property string modelData
                size: root.dotSize
                fill: modelData
                tone: cell.inMonth ? "normal" : "dim"
              }
            }
          }
        }
      }
    }
  }

  // Up goes back in time, as scrolling up a page would.
  WheelSteps {
    anchors.fill: parent
    acceptedButtons: Qt.NoButton
    onStepped: up => root.stepped(up ? -1 : 1)
  }
}
