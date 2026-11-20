pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
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
  // The conversation's width, which a bubble takes most of at most: read from the conversation, not the exchange, whose width its bubbles make.
  property real threadWidth: 0
  // Every key the panel takes, for `?`.
  readonly property var help: [
    { key: "Tab", desc: "The prompt, and back" },
    { key: "Shift+Return", desc: "A new line" },
    { key: "Ctrl+Shift+Return", desc: "Send in the background" },
    { key: "Ctrl+y", desc: "Allow what it asks" },
    { key: "y", desc: "Copy the last answer" },
    { key: "Ctrl+l", desc: "A new conversation" },
    { key: "Ctrl+o", desc: "Move it to a terminal" },
    { key: "Ctrl+r", desc: "An earlier conversation" },
    { key: "Ctrl+v", desc: "Attach the clipboard's image" },
    { key: "1-9", desc: "Pick an option" },
    { key: "Escape", desc: "Step back one thing" }
  ]
  // What Return does next, as the last turn says.
  property string next: ""

  // Page Up and Down, for the conversation.
  signal paged(bool down)
  // A key of the prompt's clicked in the legend: Escape's step, or sending in the background.
  signal promptPicked(var key)

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
    property string url
    Layout.fillWidth: true
    onActivated: {
      Qt.openUrlExternally(link.url);
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
      text: panel.linkLabel(link.url)
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

  // A prompt and what came of it, drawn by its state (Exchange), then its links as rows.
  component Turn: ColumnLayout {
    id: turn
    required property int index
    readonly property var exchange: panel.plugin.exchanges[index] ?? ({})
    readonly property var drawn: panel.plugin.describe(exchange)
    readonly property var links: panel.links(exchange.reply ?? "")
    Layout.fillWidth: true
    spacing: Config.theme.spacing / 2

    Exchange {
      id: drawnExchange
      Layout.fillWidth: true
      maximumWidth: panel.threadWidth * 0.85
      question: turn.drawn.question ?? ""
      image: turn.drawn.image ?? ""
      // A line that is only a link shows once, as its row below.
      text: (turn.drawn.text ?? "").split("\n").filter(line => !/^\s*https?:\/\/\S+\s*$/.test(line)).join("\n").trim()
      phase: turn.drawn.phase ?? "answered"
      // The time too, once the wait is noticeable, which only the panel's clock counts.
      activity: [turn.drawn.activity, panel.plugin.waited >= 2 ? panel.plugin.waited + "s" : ""].filter(part => part).join(" · ")
      options: turn.drawn.options ?? []
      table: !!turn.drawn.table
      steps: turn.drawn.steps ?? []
      picking: !panel.plugin.draft
      copyable: true
      onPicked: index => panel.plugin.pick(index)
    }

    Binding {
      when: turn.index === panel.plugin.exchanges.length - 1
      target: panel
      property: "next"
      value: drawnExchange.next
    }

    Repeater {
      model: turn.links.length

      LinkRow {
        required property int index
        url: turn.links[index] ?? ""
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

    barShown: true
    statuses: true
    // Its keys on the left, the statuses Panel adds on the right.
    bar: RowLayout {
      // Only what the state changes, each while it applies; the fixed keys are `?`'s.
      KeyLegend {
        // Typing, its letters take Ctrl; waiting, they are plain.
        readonly property string chord: panel.plugin.typing ? "Ctrl+" : ""
        keys: (panel.plugin.approval ? [{ key: "Ctrl+y", what: Words.allow, clickable: true }] : [])
          .concat(!panel.plugin.typing && panel.plugin.exchanges[panel.plugin.exchanges.length - 1]?.reply ? [{ key: "y", what: Words.copy, clickable: true }] : [])
          .concat(panel.plugin.exchanges.length > 0 ? [{ key: chord + "l", what: Words.newChat, clickable: true }] : [])
          // Where an earlier conversation is wanted most: before this one starts.
          .concat(panel.plugin.exchanges.length === 0 && panel.plugin.recalls ? [{ key: chord + "r", what: Words.history, clickable: true }] : [])
          .concat(panel.plugin.choices.length > 0 ? [{ key: "1-" + panel.plugin.choices.length, what: Words.choose }] : [])
          .concat(panel.plugin.canMove ? [{ key: chord + "o", what: Words.terminal, clickable: true }] : [])
          .concat(!panel.plugin.typing ? [{ key: "?", what: Words.help, clickable: true }] : [])
          // Last, so its changing word moves nothing.
          .concat([{ key: "Escape", what: Words[panel.plugin.escapeAction], clickable: true }])
        onPicked: key => {
          if (!panel.plugin.act(key)) panel.promptPicked(key);
        }
      }

      Item {
        Layout.fillWidth: true
      }
    }

    body: ColumnLayout {
      spacing: Config.theme.padding

      // The conversation, kept scrolled to its end.
      Flickable {
        id: thread
        visible: !panel.plugin.helping
        onWidthChanged: panel.threadWidth = width
        Component.onCompleted: panel.threadWidth = width
        Layout.fillWidth: true
        Layout.preferredHeight: panel.plugin.lines * Metrics.line - panel.inputExtra
        Layout.leftMargin: Config.theme.itemPaddingX
        Layout.rightMargin: Config.theme.itemPaddingX
        clip: true
        // What scrolled away above fades out, so a cut bubble shows no edge; only while something is cut.
        layer.enabled: contentY > 0
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: fadeMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1
        }
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

          // An empty conversation says so, as an empty list does, or why it is empty: one being resumed, or one that could not be.
          Label {
            visible: panel.plugin.exchanges.length === 0
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            tone: panel.plugin.failure ? "alert" : "dim"
            text: panel.plugin.resuming ? "Resuming" + Words.ellipsis : panel.plugin.failure || "New conversation"
          }

          Repeater {
            model: panel.plugin.exchanges.length

            Turn {}
          }
        }
      }

      // The conversation's alpha while scrolled: clear at the top, opaque a line down.
      Rectangle {
        id: fadeMask
        visible: false
        layer.enabled: true
        width: thread.width
        height: thread.height
        gradient: Gradient {
          GradientStop {
            position: 0
            color: "transparent"
          }
          GradientStop {
            position: Math.min(1, Metrics.line / Math.max(1, thread.height))
            color: "black"
          }
        }
      }

      // `?`: every key the panel takes, in the conversation's place and height, so the panel holds still.
      Item {
        visible: panel.plugin.helping
        Layout.fillWidth: true
        Layout.preferredHeight: thread.Layout.preferredHeight

        KeyList {
          anchors.left: parent.left
          anchors.right: parent.right
          keys: panel.help
          // Runs as the key does, as the menu's list does.
          onPicked: key => {
            panel.plugin.helping = false;
            panel.plugin.act(key);
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
        // Who it asks until a turn says what Return does next, as the menu's input does.
        placeholder: panel.plugin.exchanges.length > 0 ? panel.next : panel.plugin.settings.placeholder.replace("{title}", panel.plugin.title)
        active: panel.plugin.typing
        key: "Tab"
        onTapped: panel.plugin.typing = true
        onUnfocused: panel.plugin.typing = false
        empty: text === "" && !panel.plugin.image
        onCleared: panel.plugin.image = ""
        onTextChanged: panel.plugin.draft = text
        Component.onCompleted: set(panel.plugin.draft)

        // Return sends, Ctrl+Shift+Return sends in the background and Shift+Return breaks the line; the rest go to the panel, as the legend's clicks do.
        onKeyPressed: event => {
          const send = MenuKeys.sends(event);
          if (send) prompt.send(send === "background");
          else if (!panel.handle(event)) return;
          event.accepted = true;
        }

        function send(background) {
          if (!panel.plugin.send(text)) return;
          clear();
          if (background) panel.plugin.shown = false;
        }

        Connections {
          target: panel

          function onPromptPicked(key) {
            if (key === "Escape") prompt.stepBack();
            else if (key === "Ctrl+Shift+Return") prompt.send(true);
          }
        }

        Connections {
          target: panel.plugin

          // The draft as Ask changes it: a failed prompt put back, or dropped with its conversation.
          function onDraftChanged() {
            if (prompt.text !== panel.plugin.draft) prompt.set(panel.plugin.draft);
          }

          function onPasteText() {
            prompt.paste();
          }
        }
      }
    }
  }
}
