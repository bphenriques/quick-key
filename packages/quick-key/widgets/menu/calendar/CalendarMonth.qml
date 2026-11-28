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
  property string title
  // Every weekday's name as long as the narrowest column holds: three letters, fewer on a narrow level.
  readonly property int weekdayLetters: width / 7 >= 3.5 * Metrics.cell ? 3 : width / 7 >= 2.5 * Metrics.cell ? 2 : 1

  signal stepped(int months)
  signal picked(var day)

  readonly property int firstDay: Clock.firstDayOfWeek
  readonly property real dotSize: Config.theme.fontSize / 2
  readonly property real dotGap: Config.theme.spacing / 4
  // More would spill into the next day.
  readonly property int maxDots: 4
  // Seven cells as wide as their dots: narrower, the grid would spill past the month onto the events.
  readonly property real minimumWidth: 7 * (maxDots * dotSize + (maxDots - 1) * dotGap + 2 * Metrics.itemPaddingX)
  // Tighter than a menu row: six weeks of them stack up.
  readonly property real cellPadding: Metrics.itemPaddingY / 2
  // By month, so a day picked within it rebuilds nothing.
  readonly property int year: selected.getFullYear()
  readonly property int month: selected.getMonth()
  // Six weeks from the one holding the 1st, so the grid never changes height.
  readonly property var days: {
    const first = new Date(year, month, 1);
    const lead = (first.getDay() - firstDay + 7) % 7;
    return Array.from({ length: 42 }, (_, i) => new Date(first.getFullYear(), first.getMonth(), 1 - lead + i));
  }

  // The last week ends on a menu row's padding, the half its cells give up added back.
  implicitHeight: titleLabel.implicitHeight + Metrics.itemPaddingY + grid.implicitHeight + cellPadding

  Label {
    id: titleLabel
    x: Metrics.itemPaddingX
    // As a day's heading beside it, so the two start on one line.
    topPadding: Config.theme.spacing / 2
    strong: true
    text: root.title
  }

  GridLayout {
    id: grid
    anchors.top: titleLabel.bottom
    anchors.topMargin: Metrics.itemPaddingY
    anchors.left: parent.left
    anchors.right: parent.right
    columns: 7
    // Every column as wide as the rest, whatever its day holds (today, its dots).
    uniformCellWidths: true
    columnSpacing: 0
    rowSpacing: 0

    Repeater {
      model: 7

      Label {
        required property int index
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.bottomMargin: Metrics.itemPaddingY
        horizontalAlignment: Text.AlignHCenter
        tone: "dim"
        // Some locales' short names are whole words (pt: segunda): three letters, fewer where the column is narrower.
        Layout.minimumWidth: 0
        text: Clock.weekdays[(root.firstDay + index) % 7].slice(0, root.weekdayLetters)
      }
    }

    Repeater {
      model: root.days

      ListItem {
        id: cell
        required property date modelData
        readonly property bool isToday: modelData.toDateString() === Clock.date.toDateString()
        readonly property bool inMonth: modelData.getMonth() === root.month
        readonly property var colors: Calendar.enabled ? Calendar.colorsOn(modelData) : []
        // Past the dots there is room for, the last says there are more.
        readonly property bool more: colors.length > root.maxDots

        Layout.fillWidth: true
        Layout.preferredWidth: 1
        verticalPadding: root.cellPadding
        current: modelData.toDateString() === root.selected.toDateString()
        onActivated: root.picked(cell.modelData)

        ColumnLayout {
          Layout.fillWidth: true
          spacing: root.dotGap

          // Filling the cell lets the column fill it too (a layout grows no wider than its children), so number, dots and highlight share one centre.
          Label {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            tone: cell.isToday ? "primary" : cell.inMonth ? "normal" : "dim"
            strong: cell.isToday
            text: cell.modelData.getDate()
          }

          // Room for the dots whether a day has events or not, so the grid holds still.
          Row {
            visible: Calendar.enabled
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredHeight: root.dotSize
            spacing: root.dotGap

            Repeater {
              model: cell.colors.slice(0, cell.more ? root.maxDots - 1 : root.maxDots)

              Swatch {
                required property string modelData
                size: root.dotSize
                fill: modelData
                tone: cell.inMonth ? "normal" : "dim"
              }
            }

            Swatch {
              visible: cell.more
              size: root.dotSize
              fill: Tone.color("normal")
              tone: "dim"
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
