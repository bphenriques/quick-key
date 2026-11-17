pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Wayland
import qs
import qs.ui

// Ask's panel in the middle of the screen while shown: the conversation, the prompt and its keys, over the state in Ask.qml.
Scope {
  id: panel

  required property var plugin

  // The web links in a reply, each once, without the punctuation that ends a sentence.
  function links(text) {
    const found = (text.match(/https?:\/\/[^\s<>"'()\[\]]+/g) ?? []).map(url => url.replace(/[.,;:!?]+$/, ""));
    return [...new Set(found)];
  }

  // A link as read: its host, then the last part of its path (recipes.example.com › bacalhau-com-natas).
  function linkLabel(url) {
    const [, host, path] = url.match(/^https?:\/\/([^\/?#]+)([^?#]*)/) ?? [null, url, ""];
    const last = path.split("/").filter(part => part !== "").pop();
    if (!last) return host;
    let page = last;
    try {
      page = decodeURIComponent(last);
    } catch (error) {}
    return host + " › " + page.replace(/\.html?$/, "");
  }

  // Opened by the desktop's link handler, design rule 2's one exception; the panel hides so the browser shows.
  component LinkRow: ListItem {
    id: link
    required property string modelData
    Layout.fillWidth: true
    onActivated: {
      Qt.openUrlExternally(link.modelData);
      panel.plugin.shown = false;
    }

    Icon {
      tone: "primary"
      glyph: Glyphs.link
      size: Metrics.line
    }

    Label {
      Layout.fillWidth: true
      tone: "primary"
      elide: Text.ElideMiddle
      text: panel.linkLabel(link.modelData)
    }
  }

  // An image sent or about to be, four lines tall and as wide as its shape, so a screenshot gets no bands.
  component Thumbnail: Image {
    property string path
    visible: path !== ""
    source: path ? "file://" + path : ""
    fillMode: Image.PreserveAspectFit
    sourceSize.height: Metrics.line * 4
    Layout.preferredHeight: Metrics.line * 4
    Layout.preferredWidth: implicitHeight > 0 ? Layout.preferredHeight * implicitWidth / implicitHeight : 0
  }

  // A prompt and what came of it: the reply (selectable, copied as selected), its links, or the wait for it.
  component Exchange: ColumnLayout {
    id: exchange
    required property var modelData
    required property int index
    readonly property bool waiting: panel.plugin.busy && index === panel.plugin.exchanges.length - 1
    readonly property real indent: Metrics.line + Config.theme.spacing
    Layout.fillWidth: true
    spacing: Config.theme.spacing / 2

    RowLayout {
      Layout.fillWidth: true
      spacing: Config.theme.spacing

      Icon {
        Layout.alignment: Qt.AlignTop
        tone: "dim"
        glyph: Glyphs.submenu
        size: Metrics.line
      }

      Label {
        Layout.fillWidth: true
        tone: "dim"
        wrapMode: Text.Wrap
        text: exchange.modelData.prompt
      }
    }

    Thumbnail {
      Layout.leftMargin: exchange.indent
      path: exchange.modelData.image ?? ""
    }

    TextField {
      Layout.fillWidth: true
      Layout.leftMargin: exchange.indent
      visible: text !== ""
      // A stop was asked for, so it only reports; a failure needs attention.
      tone: exchange.modelData.stopped ? "dim" : exchange.modelData.error ? "warning" : "normal"
      // A line that is only a link shows once, as its row below.
      text: exchange.modelData.error || exchange.modelData.reply.split("\n").filter(line => !/^\s*https?:\/\/\S+\s*$/.test(line)).join("\n").trim()
      readOnly: true
      selectByMouse: true
      persistentSelection: true
      activeFocusOnPress: false
      copyOnSelect: true
    }

    Repeater {
      model: panel.links(exchange.modelData.reply)

      LinkRow {
        Layout.leftMargin: exchange.indent - Config.theme.itemPaddingX
      }
    }

    // An approval needs attention; the rest only reports: the tool in use, and the time once the wait is noticeable.
    RowLayout {
      visible: exchange.waiting
      Layout.leftMargin: exchange.indent
      spacing: Config.theme.spacing

      Spinner {
        tone: "dim"
        size: Metrics.line
        mood: panel.plugin.approval ? "attention" : "working"
      }

      Label {
        Layout.fillWidth: true
        tone: panel.plugin.approval ? "warning" : "dim"
        wrapMode: Text.Wrap
        text: panel.plugin.approval ? "Allow " + panel.plugin.approval + "?" : panel.plugin.activity ? panel.plugin.activity + " · " + panel.plugin.waited + "s" : panel.plugin.waited >= 2 ? panel.plugin.waited + "s" : ""
      }
    }
  }

  LazyLoader {
    active: panel.plugin.shown

    OverlayWindow {
      anchors.top: true
      anchors.bottom: true
      anchors.left: true
      anchors.right: true
      WlrLayershell.namespace: panel.plugin.name
      WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
      BackgroundEffect.blurRegion: Region {
        item: card
        radius: Config.theme.radius
      }

      // A click beside the panel hides it, the conversation kept.
      MouseArea {
        anchors.fill: parent
        onClicked: panel.plugin.shown = false
      }

      Shadow {
        anchors.fill: card
        radius: card.radius
      }

      Surface {
        id: card
        anchors.centerIn: parent
        width: Config.menu.width
        height: content.implicitHeight + 2 * Config.theme.padding

        MouseArea {
          anchors.fill: parent
        }

        ColumnLayout {
          id: content
          anchors.verticalCenter: parent.verticalCenter
          anchors.left: parent.left
          anchors.right: parent.right
          anchors.margins: Config.theme.padding
          spacing: Config.theme.padding

          RowLayout {
            Layout.fillWidth: true
            Layout.leftMargin: Config.theme.itemPaddingX
            Layout.rightMargin: Config.theme.itemPaddingX
            spacing: Config.theme.spacing

            Icon {
              glyph: panel.plugin.glyph
              size: Metrics.line
            }

            Label {
              Layout.fillWidth: true
              font.bold: true
              text: panel.plugin.title
            }
          }

          // Only the keys no one would guess (Return sends, as in any chat), each while it applies.
          KeyLegend {
            keys: [{ key: "Shift+Return", what: "newline" }]
              .concat(panel.plugin.approval ? [{ key: "Ctrl+y", what: "allow", clickable: true }] : [])
              .concat(panel.plugin.exchanges.length > 0 ? [{ key: "Ctrl+l", what: "new", clickable: true }] : [])
              .concat(panel.plugin.canMove ? [{ key: "Ctrl+o", what: "Move to terminal...", clickable: true }] : [])
              // Last, so its changing word moves nothing; twice quickly hides (docs/src/plugins.md).
              .concat([{ key: "Escape", what: panel.plugin.escapeAction, clickable: true }])
            onPicked: key => panel.plugin.act(key)
          }

          Divider {
            Layout.fillWidth: true
          }

          ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: panel.plugin.lines * Metrics.line
            Layout.leftMargin: Config.theme.itemPaddingX
            Layout.rightMargin: Config.theme.itemPaddingX
            // History and prompt as far apart as two exchanges.
            spacing: Config.theme.padding

            // The conversation, kept scrolled to its end.
            Flickable {
              id: thread
              Layout.fillWidth: true
              Layout.fillHeight: true
              clip: true
              contentHeight: exchangeList.implicitHeight
              boundsBehavior: Flickable.StopAtBounds
              onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
              onHeightChanged: contentY = Math.max(0, contentHeight - height)

              function page(down) {
                contentY = Math.max(0, Math.min(contentHeight - height, contentY + (down ? 1 : -1) * height * 0.8));
              }

              ColumnLayout {
                id: exchangeList
                width: thread.width
                // Wider between exchanges than within one, so each reads as a unit.
                spacing: Config.theme.padding

                Repeater {
                  model: panel.plugin.exchanges

                  Exchange {}
                }
              }
            }

            Divider {
              Layout.fillWidth: true
            }

            // Pasted for the next prompt; Escape clears it with the text.
            Thumbnail {
              Layout.leftMargin: Metrics.line + Config.theme.spacing
              path: panel.plugin.image
            }

            RowLayout {
              Layout.fillWidth: true
              spacing: Config.theme.spacing

              Icon {
                Layout.alignment: Qt.AlignTop
                tone: "primary"
                glyph: Glyphs.submenu
                size: Metrics.line
              }

              TextArea {
                id: prompt
                Layout.fillWidth: true
                Layout.preferredHeight: implicitHeight
                placeholder: "Ask " + panel.plugin.title
                onTextChanged: panel.plugin.draft = text
                Component.onCompleted: set(panel.plugin.draft)

                // Return sends and Shift+Return breaks the line; the rest go to panel.plugin.act, as the legend's clicks do.
                onKeyPressed: event => {
                  const plain = !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier));
                  if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && plain) {
                    if (panel.plugin.send(text)) clear();
                  } else if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
                    thread.page(event.key === Qt.Key_PageDown);
                  } else if (!panel.plugin.act(MenuKeys.name(event))) {
                    return;
                  }
                  event.accepted = true;
                }

                Connections {
                  target: panel.plugin

                  function onRestore(text) {
                    if (prompt.text === "") prompt.set(text);
                  }

                  function onClearPrompt() {
                    prompt.clear();
                  }

                  function onPasteText() {
                    prompt.paste();
                  }
                }
              }
            }
          }
        }
      }
    }
  }
}
