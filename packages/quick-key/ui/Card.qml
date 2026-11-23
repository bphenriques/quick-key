pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs

// A card that comes and goes on its own (a notification); its keys have their room at rest, so showing them moves nothing.
Surface {
  id: root

  // An app's icon at a glyph's size, recoloured by `recolour` (Icon's); its column stays without one while `iconColumn`, so every card's text starts in one place, which its owner turns off when no card has one.
  property string icon: ""
  property bool iconColumn: true
  property string recolour: "colour"
  // A picture (album art, a screenshot) on the right, square and three lines tall.
  property string image: ""
  property string title: ""
  // Who or what it is from, on the title's right.
  property string aside: ""
  property string body: ""
  // From 0 to 1, with `meterText` beside it; below 0, none.
  property real meter: -1
  property string meterText: ""
  // Each { desc, key, run }, with a `glyph` or an icon `source` before its label, in order, on the side `actionSide` names, from the glyph's column to the edge.
  property var actions: []
  property string actionSide: "right"
  // In the actions' place while set (a reply's prompt, what was sent), so the card never grows; it has the keys.
  property Component footer: null
  // Alert for what must not be missed: its border, the glyph beside `aside` and the meter, so colour is not all that says so.
  property string tone: ""
  // Its digit in the gutter, the keys on its actions and `closeKey` in its ✕'s place, shown while `keysShown`; an action's and the close key only while `current`.
  property string key: ""
  property string closeKey: ""
  property bool keysShown: false
  property bool current: false
  readonly property bool hovered: pointer.hovered
  readonly property bool acting: keysShown && current
  // The actions in rows as wide as fit, in their order, by characters as the font is monospace: whole, wrapping rather than cut, and the card's height is set as it comes, so nothing moves; from its width, which it has before its layout does.
  readonly property var rows: {
    const room = Math.floor((width - 2 * Config.theme.padding - Metrics.cell - Config.theme.spacing) / Metrics.cell);
    const rows = [];
    let used = room;
    actions.forEach((action, i) => {
      // An icon takes a glyph's width, about two characters, and one after it.
      const chars = (action.desc ?? "").length + (action.key ? MenuKeys.label(action.key).length + 1 : 0) + (action.glyph || action.source ? 3 : 0);
      if (used + actionGap + chars > room) {
        rows.push([]);
        used = -actionGap;
      }
      used += actionGap + chars;
      rows[rows.length - 1].push(i);
    });
    return rows;
  }
  // Characters between two actions: twice the one between a key and its label, so each key reads with its own, as in a legend.
  readonly property int actionGap: 2

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

  // Over the whole card, its actions and ✕ included, which take their own clicks.
  HoverHandler {
    id: pointer
  }

  MouseArea {
    id: mouse
    anchors.fill: parent
    acceptedButtons: Qt.LeftButton | Qt.MiddleButton | Qt.RightButton
    onClicked: event => event.button === Qt.RightButton ? root.dismissed() : root.activated()
  }

  ColumnLayout {
    id: layout
    anchors.fill: parent
    anchors.margins: Config.theme.padding
    spacing: Config.theme.itemPaddingY

    RowLayout {
      Layout.fillWidth: true
      spacing: Config.theme.spacing

      Label {
        id: gutter
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: Metrics.cell
        tone: "primary"
        text: root.keysShown ? root.key : ""
      }

      Item {
        Layout.alignment: Qt.AlignTop
        visible: root.iconColumn
        implicitWidth: Config.theme.iconSize
        implicitHeight: Config.theme.iconSize

        Icon {
          anchors.centerIn: parent
          source: root.icon
          recolour: root.recolour
          tone: "normal"
        }
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
            title: true
            tone: "normal"
            text: root.title
          }

          Icon {
            visible: root.tone !== ""
            size: Metrics.line
            tone: root.tone
            glyph: Glyphs.urgent
          }

          // A third of the width at most, so a long app name never takes the title's room; preferred as its text, rounded up, so a new name never keeps a stale width.
          Label {
            visible: text !== ""
            Layout.preferredWidth: Math.min(Math.ceil(implicitWidth), root.width / 3)
            elide: Text.ElideRight
            tone: "dim"
            text: root.aside
          }
        }

        Label {
          Layout.fillWidth: true
          visible: root.body !== ""
          wrapMode: Text.Wrap
          maximumLineCount: 2
          elide: Text.ElideRight
          tone: "normal"
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
      }

      Image {
        Layout.alignment: Qt.AlignTop
        Layout.preferredWidth: 3 * Metrics.line
        Layout.preferredHeight: 3 * Metrics.line
        visible: root.image !== ""
        source: root.image
        sourceSize: Qt.size(6 * Metrics.line, 6 * Metrics.line)
        fillMode: Image.PreserveAspectCrop
        mipmap: true
        // Off the GUI thread: a screenshot decodes in tens of milliseconds, and its place is already kept.
        asynchronous: true
      }

      // Its ✕ in a column of its own, mirroring the digit's, so the text ends on one edge; its key in the ✕'s place while the keys are on it.
      Item {
        Layout.alignment: Qt.AlignTop
        implicitWidth: Metrics.line
        implicitHeight: Metrics.line

        KeyHint {
          anchors.centerIn: parent
          visible: root.acting && !close.containsMouse
          key: root.closeKey
        }

        Icon {
          anchors.centerIn: parent
          visible: close.containsMouse || root.hovered && !root.acting
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

    ColumnLayout {
      id: actionArea
      Layout.fillWidth: true
      Layout.leftMargin: gutter.width + Config.theme.spacing
      // The card's width, never its own: actions asking for theirs would widen the card past its edge.
      Layout.preferredWidth: 0
      visible: root.actions.length > 0 && root.footer === null
      spacing: 0

      Repeater {
        model: root.rows.length

        RowLayout {
          id: actionRow
          required property int index
          readonly property var row: root.rows[index] ?? []
          Layout.fillWidth: true
          spacing: root.actionGap * Metrics.cell

          // Only on the open side: a hidden one takes no spacing, so the actions meet the edge.
          Item {
            visible: root.actionSide !== "left"
            Layout.fillWidth: true
          }

          Repeater {
            model: actionRow.row.length

            Item {
              id: action
              required property int index
              readonly property var entry: root.actions[actionRow.row[index]] ?? ({})
              implicitWidth: entryRow.implicitWidth
              implicitHeight: entryRow.implicitHeight

              Row {
                id: entryRow

                KeyCell {
                  id: actionKey
                  key: action.entry.key ?? ""
                }

                Icon {
                  id: actionIcon
                  anchors.verticalCenter: parent.verticalCenter
                  // Beside its label, in its colour: a theme's icon drawn for another background would vanish.
                  recolour: "tint"
                  visible: glyph !== "" || source !== ""
                  size: Metrics.line
                  tone: hover.containsMouse ? "primary" : "normal"
                  glyph: action.entry.glyph ?? ""
                  source: action.entry.source ?? ""
                }

                // A gap after the icon as an item, not the label's padding, which its width would read back.
                Item {
                  id: iconGap
                  visible: actionIcon.visible
                  width: Metrics.cell
                  height: 1
                }

                // Shortened only when one alone is wider than the card.
                Label {
                  width: Math.min(implicitWidth, actionArea.width - actionKey.implicitWidth - (actionIcon.visible ? actionIcon.width + iconGap.width : 0))
                  elide: Text.ElideRight
                  tone: hover.containsMouse ? "primary" : "normal"
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
      }
    }

    Loader {
      Layout.fillWidth: true
      // From the icon's column, so a prompt's glyph sits there; without one, from the gutter.
      Layout.leftMargin: root.iconColumn ? gutter.width + Config.theme.spacing : 0
      Layout.preferredWidth: 0
      // The actions' rows, held while the footer takes their place, so the card keeps its height.
      Layout.minimumHeight: Math.max(1, root.rows.length) * Metrics.line
      active: root.footer !== null
      visible: active
      // Only the picked card's, as delegates that changed card would otherwise take the keys from the prompt.
      focus: active && root.current
      sourceComponent: root.footer
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
