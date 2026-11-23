pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui

// Every event under a heading per day (Calendar.timeline), from the selected day on, the focused one kept in view.
ListView {
  id: root

  required property var selected
  property string focused: ""
  // Whether the focused event shows whole, over the rows below it.
  property bool details: false

  signal picked(var row)

  readonly property string selectedKey: Clock.dayKey(selected)

  // The timeline, with the selected day in it even when it has no events; kept apart from `model`, which cannot be read while ListView replaces it.
  readonly property var rows: {
    const at = Calendar.timeline.findIndex(row => row.key >= selectedKey);
    if (at >= 0 && Calendar.timeline[at].key === selectedKey) return Calendar.timeline;
    const before = at < 0 ? Calendar.timeline.length : at;
    const day = Clock.parse(selectedKey);
    return Calendar.timeline.slice(0, before).concat([{ id: "", key: selectedKey, day, event: null }], Calendar.timeline.slice(before));
  }

  // An array model, unlike the kit's count models: sections need roles, and rows change as a day is picked or the file read, not under the pointer.
  model: rows

  clip: true
  spacing: Config.theme.spacing / 2
  boundsBehavior: Flickable.StopAtBounds

  // The focused event's row, while it exists, for its details to sit over.
  property Item focusedItem: null

  // Keeps the focused event, else the selected day, in view; today rests on its first timed event not over yet when the day's start leaves it out.
  function follow() {
    // Its height can be set before its rows exist.
    if (!rows) return;
    const at = rows.findIndex(row => focused ? row.id === focused : row.key === selectedKey);
    if (at < 0) return;
    positionViewAtIndex(at, focused ? ListView.Contain : ListView.Beginning);
    showHeading(at, !focused);
    const now = focused ? at : Calendar.firstOn(rows, selectedKey);
    const item = itemAtIndex(now);
    if (now > at && !(item && fits(item.y, item.height))) positionViewAtIndex(now, ListView.Beginning);
    focusedItem = focused ? itemAtIndex(at) : null;
  }

  // Room above a day's first row for its heading, the heading on top when `top`: ListView leaves either to its estimate of what is above.
  function showHeading(at, top) {
    const item = itemAtIndex(at);
    if (item && rows[at - 1]?.key !== rows[at].key && (top || item.y - contentY < headingHeight))
      contentY = Math.max(originY, item.y - headingHeight);
  }

  onModelChanged: follow()
  onSelectedKeyChanged: follow()
  onFocusedChanged: follow()
  onHeightChanged: follow()

  // The time column's lines on `day`: all day, else start to end; one running past the day says when it ends (to Sat 18:00).
  function times(event, day) {
    const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
    // An all-day event ends at the midnight after its last day.
    const ends = event.end > dayEnd ? Words.until(Clock.dayAfter(event.allDay ? new Date(event.end - 1) : event.end, day, !event.allDay)) : "";
    if (event.allDay || (event.start <= day && event.end >= dayEnd)) return [Words.allDay, ends];
    if (event.start < day) return [Words.until(Clock.time(event.end)), ""];
    if (ends) return [Clock.time(event.start), ends];
    return [event.end > event.start ? Words.range(Clock.time(event.start), Clock.time(event.end)) : Clock.time(event.start), ""];
  }

  // As wide as the longest the time column says (to Sat 18:00), so titles start together.
  readonly property int timeChars: {
    const time = Clock.time(new Date(2000, 0, 1, 12, 30));
    const weekday = Clock.weekdays.reduce((longest, name) => name.length > longest.length ? name : longest);
    return Math.max(Words.until(weekday + " " + time).length, Words.range(time, time).length, Words.allDay.length);
  }
  readonly property real swatchWidth: Config.theme.fontSize / 4
  // Below about 12 characters left for titles, the times fold into each title's second line.
  readonly property bool folded: width - 2 * Config.theme.itemPaddingX - swatchWidth - timeChars * Metrics.cell - 2 * Config.theme.spacing < 12 * Metrics.cell

  // Lines a row takes: two for an end, a place, or times folded under the title.
  function lineCount(row) {
    if (!row?.event) return 1;
    return folded || times(row.event, row.day)[1] || row.event.location ? 2 : 1;
  }

  function rowHeight(row) {
    return lineCount(row) * Metrics.line + 2 * Config.theme.itemPaddingY;
  }

  // Whether it is whole in view: a sliver of a row reads as a glitch, at either edge.
  function fits(y, height) {
    return y >= contentY - 1 && y + height <= contentY + root.height + 1;
  }

  // Whether the details cover any of it: what they partly cover goes whole, as a sliver would show under them.
  function covered(y, height) {
    return card.visible && y < card.y + card.height && y + height > card.y;
  }

  readonly property real headingPadding: Config.theme.spacing / 2
  readonly property real headingHeight: Metrics.line + headingPadding
  // The last day, heading and rows, which the footer lets scroll to the top as any other day does.
  readonly property real lastDayHeight: {
    const last = rows.length ? rows[rows.length - 1].key : "";
    return rows.filter(row => row.key === last).reduce((sum, row) => sum + rowHeight(row) + spacing, headingHeight);
  }

  footer: Item {
    width: root.width
    height: Math.max(0, root.height - root.lastDayHeight)
  }

  section.property: "key"
  // Each day's heading scrolls with its rows: pinned on top, it would need a fill of its own over a translucent panel.
  section.labelPositioning: ViewSection.InlineLabels
  // ListView reuses a heading and shows it again itself, so what hides it is inside, not the heading's own `visible`.
  section.delegate: Item {
    id: day
    required property string section

    width: root.width
    implicitHeight: heading.implicitHeight

    Item {
      anchors.fill: parent
      // Only with room for its first event under it: a heading alone at the bottom says nothing.
      visible: root.fits(day.y, day.height + root.rowHeight(root.rows.find(row => row.key === day.section))) && !root.covered(day.y, day.height)

      Label {
        id: heading
        leftPadding: Config.theme.itemPaddingX
        topPadding: root.headingPadding
        tone: "dim"
        strong: true
        text: Clock.heading(Clock.parse(day.section))
      }
    }
  }

  delegate: ListItem {
    id: row
    required property var modelData
    readonly property var event: modelData.event
    readonly property var lines: event ? root.times(event, modelData.day) : ["", ""]
    readonly property bool twoLines: root.lineCount(modelData) === 2
    // What is over dims, so what is ahead stands out.
    readonly property string textTone: event && event.end <= Clock.date ? "dim" : "normal"

    width: ListView.view.width
    visible: root.fits(y, height) && !root.covered(y, height)
    enabled: !!event
    dimsWhenDisabled: false
    current: !!event && modelData.id === root.focused
    onActivated: root.picked(modelData)

    Label {
      visible: !row.event
      tone: "dim"
      text: Calendar.synced(row.modelData.day) ? Words.noEvents : Words.notSynced
    }

    Swatch {
      visible: !!row.event
      Layout.fillHeight: true
      size: root.swatchWidth
      fill: row.event?.color ?? "transparent"
      tone: row.textTone
    }

    ColumnLayout {
      visible: !!row.event && !root.folded
      Layout.minimumWidth: root.timeChars * Metrics.cell
      Layout.maximumWidth: Layout.minimumWidth
      Layout.alignment: Qt.AlignTop
      spacing: 0

      Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: row.textTone
        text: row.lines[0]
      }

      Label {
        visible: row.twoLines
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: "dim"
        text: row.lines[1]
      }
    }

    ColumnLayout {
      visible: !!row.event
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: 0

      Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: row.textTone
        text: row.event?.title ?? ""
      }

      Label {
        visible: row.twoLines
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: "dim"
        text: root.folded ? Words.beside([row.lines.filter(line => line).join(" "), row.event?.location]) : row.event?.location ?? ""
      }
    }
  }

  // The focused event whole, over the rows below it, or above where the list ends.
  Surface {
    id: card
    readonly property var row: root.focusedItem ? root.focusedItem.modelData : null

    // Among the rows, so it scrolls with them; ListView keeps its own children apart.
    parent: root.contentItem
    visible: root.details && !!row?.event
    // Over the rows and their headings, which ListView raises itself.
    z: 10
    width: root.width
    height: whole.implicitHeight + 2 * Config.theme.itemPaddingY
    y: root.focusedItem ? Math.max(root.contentY, Math.min(root.focusedItem.y, root.contentY + root.height - height)) : 0
    radius: Config.theme.itemRadius
    // Opaque, as the rows it covers would show through.
    color: Tone.surface(1)

    ColumnLayout {
      id: whole
      x: Config.theme.itemPaddingX
      y: Config.theme.itemPaddingY
      width: card.width - 2 * Config.theme.itemPaddingX
      spacing: 0

      Label {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        strong: true
        text: card.row?.event?.title ?? ""
      }

      Label {
        Layout.fillWidth: true
        tone: "dim"
        text: card.row?.event ? root.times(card.row.event, card.row.day).filter(line => line).join(" ") : ""
      }

      Label {
        visible: text !== ""
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        tone: "dim"
        text: card.row?.event?.location ?? ""
      }
    }
  }
}
