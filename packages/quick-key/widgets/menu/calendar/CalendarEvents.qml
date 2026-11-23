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
  // Whether the focused event shows whole, in the place of the rows.
  property bool details: false
  // Whether today's events that are over show a row each (CalendarModel.unfolded).
  property bool unfolded: false

  signal picked(var row)

  readonly property string selectedKey: Clock.dayKey(selected)

  // The timeline, with the selected day in it even when it has no events; kept apart from `model`, which cannot be read while ListView replaces it.
  readonly property var rows: {
    const ids = earlierIds ? earlierIds.split("\n") : [];
    const at = Calendar.timeline.findIndex(row => row.key >= selectedKey);
    if (at >= 0 && Calendar.timeline[at].key === selectedKey) return fold(Calendar.timeline, ids);
    const before = at < 0 ? Calendar.timeline.length : at;
    const day = Clock.parse(selectedKey);
    return fold(Calendar.timeline.slice(0, before).concat([{ id: "", key: selectedKey, day, event: null }], Calendar.timeline.slice(before)), ids);
  }

  // Today's events that are over, by id: a string, so the clock's minute rebuilds the rows only as one ends.
  readonly property string earlierIds: unfolded ? "" : Calendar.timeline.filter(row => Calendar.earlier(row)).map(row => row.id).join("\n")

  // `rows` with those of `ids` folded into one line where the first was, so what is over leaves today's heading and what is next in view.
  function fold(rows, ids) {
    const first = rows.find(row => ids.includes(row.id));
    if (!first) return rows;
    const line = { id: first.key + " earlier", key: first.key, day: first.day, event: null, earlier: rows.filter(row => ids.includes(row.id)).map(row => row.event) };
    return rows.filter(row => row === first || !ids.includes(row.id)).map(row => row === first ? line : row);
  }

  // An array model, unlike the kit's count models: sections need roles, and rows change as a day is picked or the file read, not under the pointer.
  model: rows

  clip: true
  spacing: Config.theme.spacing / 2
  boundsBehavior: Flickable.StopAtBounds
  // Still while the details hold its place.
  interactive: !details

  // The focused event's row while it shows whole.
  readonly property var detailRow: details ? rows.find(row => row.id === focused) ?? null : null

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
  // A row's height follows the width (folded), which the level lays out after the height.
  onWidthChanged: follow()

  // The time column's lines on `day`: all day, else start to end; one running past the day says when it ends (to Sat 18:00), to the minute when `whole`.
  function times(event, day, whole) {
    const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
    // An all-day event ends at the midnight after its last day.
    const last = event.allDay ? new Date(event.end - 1) : event.end;
    const ends = event.end > dayEnd ? Words.until(whole ? Clock.when(last, !event.allDay) : Clock.dayAfter(last, day, !event.allDay)) : "";
    if (event.allDay || (event.start <= day && event.end >= dayEnd)) return [Words.allDay, ends];
    if (event.start < day) return [Words.until(Clock.time(event.end)), ""];
    if (ends) return [Clock.time(event.start), ends];
    return [event.end > event.start ? Words.range(Clock.time(event.start), Clock.time(event.end)) : Clock.time(event.start), ""];
  }

  // As wide as the longest the time column says (to Sat 18:00, to 28 Nov), so titles start together.
  readonly property int timeChars: {
    const from = new Date(2000, 0, 1);
    const time = Clock.time(new Date(2000, 0, 1, 12, 30));
    // Each weekday within a week of `from`, then each month's date beyond it.
    const ends = Array.from({ length: 19 }, (_, i) => i < 7 ? new Date(2000, 0, 1 + i, 12, 30) : new Date(2000, i - 7, 28, 12, 30));
    return Math.max(...ends.map(end => Words.until(Clock.dayAfter(end, from, true)).length), Words.range(time, time).length, Words.allDay.length);
  }
  readonly property real swatchWidth: Config.theme.fontSize / 4
  // Below about 12 characters left for titles, the times fold into each title's second line.
  readonly property bool folded: width - 2 * Metrics.itemPaddingX - swatchWidth - timeChars * Metrics.cell - 2 * Config.theme.spacing < 12 * Metrics.cell

  // Lines a row takes: two for an end, a place, or times folded under the title.
  function lineCount(row) {
    if (!row?.event) return 1;
    return folded || times(row.event, row.day)[1] || row.event.location ? 2 : 1;
  }

  function rowHeight(row) {
    return lineCount(row) * Metrics.line + 2 * Metrics.itemPaddingY;
  }

  // Whether it is whole in view: a sliver of a row reads as a glitch, at either edge.
  function fits(y, height) {
    return y >= contentY - 1 && y + height <= contentY + root.height + 1;
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
    id: group
    required property string section

    width: root.width
    implicitHeight: heading.implicitHeight

    Item {
      anchors.fill: parent
      // Only with room for its first event under it: a heading alone at the bottom says nothing.
      visible: !root.details && root.fits(group.y, group.height + root.rowHeight(root.rows.find(row => row.key === group.section)))

      DayHeading {
        id: heading
        day: Clock.parse(group.section)
      }
    }
  }

  component DayHeading: Label {
    required property var day

    leftPadding: Metrics.itemPaddingX
    topPadding: root.headingPadding
    tone: "dim"
    strong: true
    text: Clock.heading(day)
  }

  delegate: ListItem {
    id: row
    required property var modelData
    readonly property var event: modelData.event
    // Today's events that are over, when this row is the one line they fold into.
    readonly property var earlier: modelData.earlier ?? null
    readonly property string earlierTitles: earlier ? earlier.map(event => event.title).join(", ") : ""
    readonly property var lines: event ? root.times(event, modelData.day) : ["", ""]
    readonly property bool twoLines: root.lineCount(modelData) === 2
    // What is over dims, so what is ahead stands out.
    readonly property string textTone: event && event.end > Clock.date ? "normal" : "dim"

    width: ListView.view.width
    visible: !root.details && root.fits(y, height)
    enabled: !!event
    dimsWhenDisabled: false
    current: !!event && modelData.id === root.focused
    onActivated: root.picked(modelData)

    Label {
      visible: !row.event && !row.earlier
      tone: "dim"
      text: Calendar.synced(row.modelData.day) ? Words.noEvents : Words.notSynced
    }

    Swatch {
      visible: !!row.event || !!row.earlier
      Layout.fillHeight: true
      size: root.swatchWidth
      fill: row.event?.color ?? "transparent"
      // Dimmed, transparent would turn black: the folded line keeps the place, not a colour.
      tone: row.event ? row.textTone : "normal"
    }

    ColumnLayout {
      visible: (!!row.event || !!row.earlier) && !root.folded
      Layout.minimumWidth: root.timeChars * Metrics.cell
      Layout.maximumWidth: Layout.minimumWidth
      Layout.alignment: Qt.AlignTop
      spacing: 0

      Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: row.textTone
        text: row.earlier ? Words.earlier(row.earlier.length) : row.lines[0]
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
      visible: !!row.event || !!row.earlier
      Layout.fillWidth: true
      Layout.alignment: Qt.AlignTop
      spacing: 0

      Label {
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: row.textTone
        text: !row.earlier ? row.event?.title ?? "" : root.folded ? Words.beside([Words.earlier(row.earlier.length), row.earlierTitles]) : row.earlierTitles
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

  // The focused event whole under its day, in the place of the rows until Escape: a change of surface, as opening a level is.
  ColumnLayout {
    // Beside the rows, not among them, so it holds still at the top.
    parent: root
    visible: !!root.detailRow
    width: root.width
    spacing: 0

    DayHeading {
      day: root.detailRow?.day ?? Clock.date
    }

    ListItem {
      Layout.fillWidth: true
      current: true

      Swatch {
        Layout.fillHeight: true
        size: root.swatchWidth
        fill: root.detailRow?.event?.color ?? "transparent"
      }

      ColumnLayout {
        Layout.fillWidth: true
        spacing: 0

        Label {
          Layout.fillWidth: true
          wrapMode: Text.Wrap
          strong: true
          text: root.detailRow?.event?.title ?? ""
        }

        Label {
          Layout.fillWidth: true
          wrapMode: Text.Wrap
          tone: "dim"
          text: root.detailRow ? root.times(root.detailRow.event, root.detailRow.day, true).filter(line => line).join(" ") : ""
        }

        Label {
          visible: text !== ""
          Layout.fillWidth: true
          wrapMode: Text.Wrap
          tone: "dim"
          text: root.detailRow?.event?.location ?? ""
        }
      }
    }
  }
}
