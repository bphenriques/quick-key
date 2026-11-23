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
  // Every key the panel takes, for `?`: Ask's table, the one its legend and its keys read too.
  readonly property var help: plugin.keys
  // The last turn as drawn, for what Return does next.
  readonly property var last: plugin.exchanges.length > 0 ? plugin.describe(plugin.exchanges[plugin.exchanges.length - 1]) : null
  // An answer's selection, kept while its turn is scrolled away or the panel hidden: { turn, piece, start, end }; another conversation drops it.
  property var selection: null

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

  // A turn's answer selected (kept for it) or cleared (dropped, if it was the one kept).
  function keep(turn, selection) {
    if (selection) panel.selection = Object.assign({ turn: turn }, selection);
    else if (panel.selection && panel.selection.turn === turn) panel.selection = null;
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
      Panels.close();
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

  // A prompt and what came of it, drawn by its state (Exchange), then its links as rows.
  component Turn: ColumnLayout {
    id: turn
    required property int index
    // Its exchange's place in the conversation: the list runs from the newest up.
    readonly property int at: panel.plugin.exchanges.length - 1 - index
    readonly property var exchange: panel.plugin.exchanges[at] ?? ({})
    readonly property var drawn: panel.plugin.describe(exchange)
    readonly property var links: panel.links(exchange.reply ?? "")
    Layout.fillWidth: true
    spacing: Config.theme.spacing / 2

    Exchange {
      Layout.fillWidth: true
      maximumWidth: panel.threadWidth * 0.85
      question: turn.drawn.question ?? ""
      image: turn.drawn.image ?? ""
      // A line that is only a link shows once, as its row below.
      text: (turn.drawn.text ?? "").split("\n").filter(line => !/^\s*https?:\/\/\S+\s*$/.test(line)).join("\n").trim()
      phase: turn.drawn.phase ?? "done"
      kind: turn.drawn.kind ?? ""
      // The time too, once the wait is noticeable, which only the panel's clock counts.
      activity: [turn.drawn.activity, panel.plugin.waited >= 2 ? panel.plugin.waited + "s" : ""].filter(part => part).join(" · ")
      options: turn.drawn.options ?? []
      table: !!turn.drawn.table
      steps: turn.drawn.steps ?? []
      picking: !panel.plugin.draft
      copyable: true
      kept: panel.selection && panel.selection.turn === turn.at ? panel.selection : null
      onPicked: index => panel.plugin.pick(index)
      onSelected: selection => panel.keep(turn.at, selection)
    }

    Repeater {
      model: turn.links.length

      LinkRow {
        required property int index
        url: turn.links[index] ?? ""
      }
    }
  }

  Connections {
    target: panel.plugin

    function onSessionChanged() {
      panel.selection = null;
    }

    function onExchangesChanged() {
      if (panel.selection && panel.selection.turn >= panel.plugin.exchanges.length) panel.selection = null;
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
    onDismissed: Panels.close()

    barShown: true
    statuses: true
    // Its keys on the left, the statuses Panel adds on the right.
    bar: RowLayout {
      // Only what the state changes, each while it applies; the fixed keys are `?`'s.
      KeyLegend {
        // Each key as it runs now (Ask.typedAs): waiting, a chord's letter alone.
        keys: panel.plugin.keys.filter(entry => entry.what && entry.shows()).map(entry => ({ key: panel.plugin.typedAs(entry.key), what: entry.what, clickable: true }))
          .concat(panel.plugin.choices.length > 0 ? [{ key: "1-" + panel.plugin.choices.length, what: Words.choose }] : [])
          .concat(!panel.plugin.typing ? [{ key: "?", what: Words.help, clickable: true }] : [])
          .concat(panel.plugin.typing && (panel.plugin.draft || panel.plugin.image) ? [{ key: "Escape", what: Words.clear, clickable: true }] : [])
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

      // The conversation, built only where it shows, so a long one opens as fast as a short one; laid out from the newest up, so it rests at its end however tall the turns built meanwhile, a streaming answer growing upward.
      ListView {
        id: thread
        visible: !panel.plugin.helping
        // At the top edge the prompt is above, so the newest sits at the top and older turns run down.
        readonly property bool atTop: Config.menu.edge === "top"
        verticalLayoutDirection: atTop ? ListView.TopToBottom : ListView.BottomToTop
        onWidthChanged: panel.threadWidth = width
        Component.onCompleted: panel.threadWidth = width
        Layout.fillWidth: true
        Layout.preferredHeight: panel.plugin.lines * Metrics.line - panel.inputExtra
        Layout.leftMargin: Config.theme.itemPaddingX
        Layout.rightMargin: Config.theme.itemPaddingX
        clip: true
        // What scrolled away above fades out, so a cut bubble shows no edge; only while something is cut.
        layer.enabled: atTop ? !atYEnd : !atYBeginning
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: fadeMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1
        }
        // Wider between exchanges than within one, so each reads as a unit.
        spacing: Config.theme.padding
        boundsBehavior: Flickable.StopAtBounds
        model: panel.plugin.exchanges.length
        delegate: Turn {
          width: thread.width
        }
        // No turn is current: a ListView keeps its current item built wherever it is, and makes the first current again as its count changes.
        onCountChanged: currentIndex = -1

        function page(down) {
          // A conversation shorter than the view has nothing above to page to; laid out upward, the bound below would leave a gap.
          if (contentHeight <= height) return;
          contentY = Math.max(originY, Math.min(originY + contentHeight - height, contentY + (down ? 1 : -1) * height * 0.8));
        }

        Connections {
          target: panel

          function onPaged(down) {
            thread.page(down);
          }
        }

        // An empty conversation says so, as an empty list does, or why it is empty: one being resumed, or one that could not be.
        Label {
          // On the view itself, not its content, which a list laid out upward places out of sight while empty.
          parent: thread
          anchors.top: parent.top
          visible: panel.plugin.exchanges.length === 0
          width: thread.width
          wrapMode: Text.Wrap
          tone: panel.plugin.failure ? "alert" : "dim"
          text: panel.plugin.resuming ? panel.plugin.words.resuming : panel.plugin.failure || panel.plugin.words.newConversation
        }
      }

      // The conversation's alpha while scrolled: clear at the top, opaque a line down.
      Rectangle {
        id: fadeMask
        visible: false
        layer.enabled: true
        width: thread.width
        height: thread.height
        // Clear at the far end from the prompt.
        rotation: thread.atTop ? 180 : 0
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
        placeholder: panel.last ? Words.next(panel.last.phase, panel.last.kind, !panel.plugin.draft, panel.last.options.length) : panel.plugin.settings.placeholder.replace(/\{title\}/g, panel.plugin.title)
        active: panel.plugin.typing
        key: "Tab"
        onTapped: panel.plugin.typing = true
        onBack: Panels.back()
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
          if (background) Panels.close();
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
