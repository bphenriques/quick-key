pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.ui

// An island's level (LevelModel): its rows, its view, its actions and its error; the body's also lists a held modifier's keys.
ColumnLayout {
  id: body

  required property MenuModel menu
  required property LevelModel level
  readonly property bool hinting: level === menu.body && menu.hints.length > 0
  // Its height before a held modifier listed its keys, which it keeps while they show, so the panel holds still.
  property real restHeight: 0
  onImplicitHeightChanged: if (!hinting) restHeight = implicitHeight
  spacing: Config.theme.padding

  // Fewer keys than rows leave the body's far side empty rather than shrink it, the keys next to the bar, below it.
  Item {
    visible: body.hinting && body.restHeight > hints.implicitHeight + body.spacing
    Layout.preferredHeight: body.restHeight - hints.implicitHeight - body.spacing
  }

  // The keys a held modifier reaches, in the body's own columns; each still runs on a click.
  GridLayout {
    id: hints
    Layout.fillWidth: true
    visible: body.hinting
    columns: body.level.columns
    columnSpacing: Metrics.columnGap
    rowSpacing: 0

    Repeater {
      model: body.hinting ? body.menu.hints.length : 0

      MenuRow {
        required property int index
        item: body.menu.hints[index] ?? ({})
        menu: body.menu
        level: body.level
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        chars: body.menu.keyChars(body.menu.hints)
        live: true
      }
    }
  }

  // Filtering, as tall as its rows were, so nothing moves as the filter narrows.
  ColumnLayout {
    Layout.fillWidth: true
    Layout.preferredHeight: body.level.filtering ? body.level.filterSlots * filledRow.implicitHeight : -1
    visible: !body.hinting && (body.level.rows.length > 0 || body.level.filtering || body.level.emptyText !== "")
    spacing: 0

    // A filled row's height, for the rows held while filtering.
    MenuRow {
      id: filledRow
      visible: false
      menu: body.menu
      level: body.level
      item: ({ key: "1", desc: "x", icon: Glyphs.search })
    }

    Label {
      visible: body.level.emptyText !== ""
      Layout.leftMargin: Metrics.itemPaddingX
      Layout.topMargin: body.level.filtering ? Metrics.itemPaddingY : 0
      tone: "dim"
      text: body.level.emptyText
    }

    Repeater {
      model: body.level.rows.length

      MenuRow {
        required property int index
        item: body.level.rows[index] ?? ({})
        menu: body.menu
        level: body.level
        Layout.fillWidth: true
        // As wide as the first column of actions too, so a list's labels start with theirs.
        chars: Math.max(body.menu.keyChars(body.level.rows), body.level.bodyActions.length ? body.level.columnChars(0, actionsGrid.columns) : 1)
      }
    }

    Item {
      visible: body.level.filtering
      Layout.fillHeight: true
    }
  }

  // A level's view (Views) with its model, built only while shown, as it is most of what an opening builds.
  Loader {
    readonly property var view: body.level.view
    Layout.fillWidth: true
    visible: !body.hinting && item !== null
    onViewChanged: setSource(view ? view.source : "", { model: body.level.viewModel })
    Component.onCompleted: if (view) setSource(view.source, { model: body.level.viewModel })
  }

  // Hidden when empty, since an empty GridLayout keeps its last height.
  GridLayout {
    id: actionsGrid
    Layout.fillWidth: true
    visible: !body.hinting && body.level.bodyActions.length > 0
    columns: body.level.columns
    columnSpacing: Metrics.columnGap
    rowSpacing: 0

    Repeater {
      model: body.level.bodyActions.length

      // At the top, values line up in equal columns; in a level, the last column hugs its rows against the right edge.
      MenuRow {
        required property int index
        item: body.level.bodyActions[index] ?? ({})
        hugs: body.level.level !== null && index % actionsGrid.columns === actionsGrid.columns - 1
        menu: body.menu
        level: body.level
        // Hugging, it fills no further than itself; not filling at all would fix it at its full width, past the card.
        Layout.fillWidth: true
        Layout.preferredWidth: hugs ? -1 : 1
        Layout.maximumWidth: hugs ? Math.ceil(implicitWidth) : Number.POSITIVE_INFINITY
        readonly property int columnChars: body.level.columnChars(index, actionsGrid.columns)
        chars: index % actionsGrid.columns === 0 && body.level.rows.length ? Math.max(columnChars, body.menu.keyChars(body.level.rows)) : columnChars
      }
    }
  }

  Label {
    Layout.fillWidth: true
    Layout.leftMargin: Metrics.itemPaddingX
    Layout.rightMargin: Metrics.itemPaddingX
    visible: !body.hinting && body.level.error !== ""
    // Alert, not warning: the warning hue sits too close to calendar colours to read as a fault.
    tone: "alert"
    wrapMode: Text.Wrap
    text: body.level.error
  }
}
