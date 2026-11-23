import QtQuick
import QtQuick.Layouts
import qs
import qs.services
import qs.ui
import qs.widgets.menu.calendar

// A calendar level (Views): the month beside its events; beside Menu, so the shell finds calendar/ by its import.
RowLayout {
  id: root

  required property CalendarModel model

  spacing: Config.theme.padding

  CalendarMonth {
    // Two fifths of the level, but room for seven columns of three characters, the events beside it giving way first.
    Layout.preferredWidth: Math.max(7 * 3.5 * Metrics.cell, root.width * 2 / 5)
    Layout.minimumWidth: minimumWidth
    Layout.alignment: Qt.AlignTop
    title: root.model.title
    selected: root.model.selected
    onStepped: months => root.model.moveSelected(0, months, 0)
    onPicked: day => root.model.select(day)
  }

  Divider {
    Layout.fillHeight: true
    visible: events.visible
  }

  CalendarEvents {
    id: events
    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.preferredWidth: 3
    Layout.preferredHeight: 0
    visible: Calendar.enabled
    selected: root.model.selected
    focused: root.model.focused
    details: root.model.details
    unfolded: root.model.unfolded
    onPicked: row => root.model.focus(row)
  }
}
