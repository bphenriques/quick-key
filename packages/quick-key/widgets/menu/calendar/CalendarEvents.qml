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
  // The row in focus, by its id; "" for none.
  property string focused: ""

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

  model: rows

  clip: true
  spacing: Config.theme.spacing / 2
  boundsBehavior: Flickable.StopAtBounds

  // Keeps the focused event, else the selected day, in view, with room above it for its day's heading.
  function follow() {
    const at = rows.findIndex(row => focused ? row.id === focused : row.key === selectedKey);
    if (at < 0) return;
    positionViewAtIndex(at, focused ? ListView.Contain : ListView.Beginning);
    const item = itemAtIndex(at);
    if (item && item.y - contentY < headingHeight)
      contentY = Math.max(originY, item.y - headingHeight);
  }

  onModelChanged: follow()
  onSelectedKeyChanged: follow()
  onFocusedChanged: follow()
  onHeightChanged: follow()

  // The left column's lines on `day`: "All day" (with its last day when later), else start and end, `…` for another day.
  function times(event, day) {
    const dayEnd = new Date(day.getFullYear(), day.getMonth(), day.getDate() + 1);
    // Ending at midnight, an event ends on the day before.
    const last = new Date(event.end - 1);
    if (event.allDay || (event.start <= day && event.end >= dayEnd))
      return ["All day", event.end > dayEnd ? "to " + Clock.format(last, "%a %-d") : ""];
    return [
      event.start < day ? "…" : Clock.format(event.start, "%H:%M"),
      event.end > dayEnd ? "…" : event.end > event.start ? Clock.format(event.end, "%H:%M") : ""
    ];
  }

  // Whether it ends in view; only the bottom counts, or the top row would blink while the list scrolls to a new day.
  function fits(y, height) {
    return y + height <= contentY + root.height + 1;
  }

  function heading(day) {
    const tomorrow = new Date(Clock.date.getFullYear(), Clock.date.getMonth(), Clock.date.getDate() + 1);
    return day.toDateString() === Clock.date.toDateString() ? "Today"
      : day.toDateString() === tomorrow.toDateString() ? "Tomorrow"
      : Clock.format(day, "%A %-d %B");
  }

  // The height of a day's first row, one line or two (an end, a place): what its heading needs below it to be shown.
  function firstRowHeight(key) {
    const first = rows.find(row => row.key === key);
    const twoLines = first?.event && (times(first.event, first.day)[1] || first.event.location);
    return (twoLines ? 2 : 1) * Metrics.line + 2 * Config.theme.itemPaddingY;
  }

  readonly property real headingPadding: Config.theme.spacing / 2
  readonly property real headingHeight: Metrics.line + headingPadding

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
      visible: root.fits(day.y, day.height + root.firstRowHeight(day.section))

      Label {
        id: heading
        leftPadding: Config.theme.itemPaddingX
        topPadding: root.headingPadding
        tone: "dim"
        font.bold: true
        text: root.heading(Clock.parse(day.section))
      }
    }
  }

  delegate: ListItem {
    id: row
    required property var modelData
    readonly property var event: modelData.event
    readonly property var lines: event ? root.times(event, modelData.day) : ["", ""]
    readonly property bool compact: !lines[1] && !event?.location

    width: ListView.view.width
    // Whole or not at all: a sliver of a row reads as a glitch.
    visible: root.fits(y, height)
    enabled: !!event
    dimsWhenDisabled: false
    current: !!event && modelData.id === root.focused
    onActivated: root.picked(modelData)

    Label {
      visible: !row.event
      tone: "dim"
      text: "No events"
    }

    Swatch {
      visible: !!row.event
      Layout.fillHeight: true
      size: Config.theme.fontSize / 4
      fill: row.event?.color ?? "transparent"
    }

    // As wide as "to Wed 30", so titles start together.
    ColumnLayout {
      visible: !!row.event
      Layout.minimumWidth: 9 * Metrics.cell
      Layout.maximumWidth: Layout.minimumWidth
      Layout.alignment: Qt.AlignTop
      spacing: 0

      Label {
        text: row.lines[0]
      }

      Label {
        visible: !row.compact
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
        text: row.event?.title ?? ""
      }

      Label {
        visible: !row.compact
        Layout.fillWidth: true
        elide: Text.ElideRight
        tone: "dim"
        text: row.event?.location ?? ""
      }
    }
  }
}
