pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import qs
import qs.ui

// Ask's panel while shown, where the menu opens: the conversation, the prompt and its keys, over the state in Ask.qml.
Scope {
  id: panel

  required property var plugin
  // How much taller than a line the prompt is, which the conversation gives up.
  property real inputExtra: 0

  // Page Up and Down, for the conversation.
  signal paged(bool down)
  // Escape clicked in the legend for a step that is the prompt's.
  signal escaped

  // A key for the panel, from the prompt or, while it waits, the panel; whether it was the panel's.
  function handle(event) {
    if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
      paged(event.key === Qt.Key_PageDown);
      return true;
    }
    return plugin.act(MenuKeys.name(event));
  }

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
    required property int index
    readonly property var turn: panel.plugin.exchanges[index] ?? ({})
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
        glyph: Glyphs.prompt
        size: Metrics.line
      }

      Label {
        Layout.fillWidth: true
        tone: "dim"
        wrapMode: Text.Wrap
        text: exchange.turn.prompt ?? ""
      }
    }

    Thumbnail {
      Layout.leftMargin: exchange.indent
      path: exchange.turn.image ?? ""
    }

    TextField {
      Layout.fillWidth: true
      Layout.leftMargin: exchange.indent
      visible: text !== ""
      // A stop was asked for, so it only reports; a failure needs attention.
      tone: exchange.turn.stopped ? "dim" : exchange.turn.error ? "alert" : "normal"
      // A line that is only a link shows once, as its row below.
      text: exchange.turn.error || (exchange.turn.reply ?? "").split("\n").filter(line => !/^\s*https?:\/\/\S+\s*$/.test(line)).join("\n").trim()
      readOnly: true
      selectByMouse: true
      persistentSelection: true
      activeFocusOnPress: false
      copyOnSelect: true
    }

    Repeater {
      model: panel.links(exchange.turn.reply ?? "")

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

  Panel {
    shown: panel.plugin.shown
    namespace: panel.plugin.name
    inputShown: true
    inputFocused: panel.plugin.typing
    // Waiting, the panel's own keys.
    onKeyPressed: event => event.accepted = panel.handle(event)
    // Hidden, the conversation is kept.
    onDismissed: panel.plugin.shown = false

    body: ColumnLayout {
      spacing: Config.theme.padding

      // Only the keys no one would guess (Return sends, as in any chat), each while it applies.
      KeyLegend {
        // Typing, its letters take Ctrl; waiting, they are plain.
        readonly property string chord: panel.plugin.typing ? "Ctrl+" : ""
        keys: (panel.plugin.typing ? [{ key: "Shift+Return", what: "newline" }] : [])
          .concat(panel.plugin.approval ? [{ key: chord + "y", what: "allow", clickable: true }] : [])
          .concat(panel.plugin.exchanges.length > 0 ? [{ key: chord + "l", what: "new", clickable: true }] : [])
          .concat(panel.plugin.canMove ? [{ key: chord + "o", what: "terminal...", clickable: true }] : [])
          // Last, so its changing word moves nothing.
          .concat([{ key: "Escape", what: panel.plugin.escapeAction, clickable: true }])
        onPicked: key => {
          if (!panel.plugin.act(key) && key === "Escape") panel.escaped();
        }
      }

      Divider {
        Layout.fillWidth: true
      }

      // The conversation, kept scrolled to its end.
      Flickable {
        id: thread
        Layout.fillWidth: true
        Layout.preferredHeight: panel.plugin.lines * Metrics.line - panel.inputExtra
        Layout.leftMargin: Config.theme.itemPaddingX
        Layout.rightMargin: Config.theme.itemPaddingX
        clip: true
        contentHeight: exchangeList.implicitHeight
        boundsBehavior: Flickable.StopAtBounds
        onContentHeightChanged: contentY = Math.max(0, contentHeight - height)
        onHeightChanged: contentY = Math.max(0, contentHeight - height)

        function page(down) {
          contentY = Math.max(0, Math.min(contentHeight - height, contentY + (down ? 1 : -1) * height * 0.8));
        }

        Connections {
          target: panel

          function onPaged(down) {
            thread.page(down);
          }
        }

        ColumnLayout {
          id: exchangeList
          width: thread.width
          // Wider between exchanges than within one, so each reads as a unit.
          spacing: Config.theme.padding

          // An empty conversation says so, as an empty list does.
          Label {
            visible: panel.plugin.exchanges.length === 0
            tone: "dim"
            text: "New conversation"
          }

          Repeater {
            model: panel.plugin.exchanges.length

            Exchange {}
          }
        }
      }
    }

    input: ColumnLayout {
      spacing: Config.theme.spacing
      // A prompt taller than a line takes its height from the conversation, so the panel holds still.
      onImplicitHeightChanged: panel.inputExtra = implicitHeight - Metrics.line

      // Pasted for the next prompt; Escape clears it with the text.
      Thumbnail {
        Layout.leftMargin: Metrics.line + Config.theme.spacing
        path: panel.plugin.image
      }

      Prompt {
        id: prompt
        Layout.fillWidth: true
        glyph: panel.plugin.settings.promptGlyph || Glyphs.prompt
        placeholder: panel.plugin.settings.placeholder.replace("{title}", panel.plugin.title)
        active: panel.plugin.typing
        key: panel.plugin.settings.key
        onTapped: panel.plugin.typing = true
        onUnfocused: panel.plugin.typing = false
        empty: text === "" && !panel.plugin.image
        onCleared: panel.plugin.image = ""
        onTextChanged: panel.plugin.draft = text
        Component.onCompleted: set(panel.plugin.draft)

        // Return sends and Shift+Return breaks the line; the rest go to the panel, as the legend's clicks do.
        onKeyPressed: event => {
          const plain = !(event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier));
          if ((event.key === Qt.Key_Return || event.key === Qt.Key_Enter) && plain) {
            if (panel.plugin.send(text)) clear();
          } else if (!panel.handle(event)) {
            return;
          }
          event.accepted = true;
        }

        Connections {
          target: panel

          function onEscaped() {
            prompt.stepBack();
          }
        }

        Connections {
          target: panel.plugin

          function onRestore(text) {
            if (prompt.text === "") prompt.set(text);
          }


          function onPasteText() {
            prompt.paste();
          }
        }
      }
    }
  }
}
