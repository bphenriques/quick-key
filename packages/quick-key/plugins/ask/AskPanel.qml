pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import Quickshell
import qs
import qs.ui
import qs.ui.conversation

Scope {
  id: panel

  required property var plugin
  // The prompt's height past a line, which the conversation gives up.
  property real inputExtra: 0
  // Read from the conversation, not the exchange, whose width its bubbles make.
  property real threadWidth: 0
  // For the placeholder.
  readonly property var last: plugin.exchanges.length > 0 ? plugin.describe(plugin.exchanges[plugin.exchanges.length - 1]) : null
  // { turn, piece, start, end }, kept while scrolled away or hidden; another conversation drops it.
  property var selection: null

  signal paged(bool down)
  // A prompt key clicked in the legend.
  signal promptPicked(var key)

  function handle(event) {
    if (event.key === Qt.Key_PageUp || event.key === Qt.Key_PageDown) {
      paged(event.key === Qt.Key_PageDown);
      return true;
    }
    return plugin.act(MenuKeys.name(event));
  }

  function keep(turn, selection) {
    if (selection) panel.selection = Object.assign({ turn: turn }, selection);
    else if (panel.selection && panel.selection.turn === turn) panel.selection = null;
  }

  // Each once, without a sentence's closing punctuation.
  function links(text) {
    const found = (text.match(/https?:\/\/[^\s<>"'()\[\]]+/g) ?? []).map(url => url.replace(/[.,;:!?]+$/, ""));
    return [...new Set(found)];
  }

  // Its host, then the last part of its path: recipes.example.com › bacalhau-com-natas.
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

  // Design rule 2's one exception; the panel hides so the browser shows.
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
      // The wait too, once noticeable.
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
    onKeyPressed: event => event.accepted = panel.handle(event)
    // Hidden, the conversation is kept.
    onDismissed: Panels.close()

    barShown: true
    statuses: true
    islands: Config.menu.islands
    bar: RowLayout {
      // The legend on an island of its own with `menu.islands`, the statuses on another.
      readonly property var islands: [legend]

      // Only what the state changes; fixed keys are listed on `?`.
      KeyLegend {
        id: legend
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

      // Built only where it shows, so a long conversation opens as fast as a short one; laid out from the newest up, so it rests at its end however tall the turns built meanwhile.
      ListView {
        id: thread
        visible: !panel.plugin.helping
        // At the top edge the prompt is above, so the newest sits at the top and older turns run down.
        verticalLayoutDirection: Config.atTop ? ListView.TopToBottom : ListView.BottomToTop
        onWidthChanged: panel.threadWidth = width
        Component.onCompleted: panel.threadWidth = width
        Layout.fillWidth: true
        Layout.preferredHeight: Math.min(panel.plugin.settings.lines * Metrics.line, (Window.height || Infinity) * 0.6) - panel.inputExtra
        Layout.leftMargin: Config.theme.itemPaddingX
        Layout.rightMargin: Config.theme.itemPaddingX
        clip: true
        // What scrolled away above fades out, so a cut bubble shows no edge; only while something is cut.
        layer.enabled: Config.atTop ? !atYEnd : !atYBeginning
        layer.effect: MultiEffect {
          maskEnabled: true
          maskSource: fadeMask
          maskThresholdMin: 0.5
          maskSpreadAtMin: 1
        }
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

        // An empty conversation says so, or that it is being resumed or could not be.
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

      // Clear at the top, opaque a line down.
      Rectangle {
        id: fadeMask
        visible: false
        layer.enabled: true
        width: thread.width
        height: thread.height
        // Clear at the far end from the prompt.
        rotation: Config.atTop ? 180 : 0
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

      // In the conversation's place and height, so the panel holds still.
      Item {
        visible: panel.plugin.helping
        Layout.fillWidth: true
        Layout.preferredHeight: thread.Layout.preferredHeight

        KeyList {
          anchors.left: parent.left
          anchors.right: parent.right
          keys: panel.plugin.keys
          onPicked: key => panel.plugin.runListed(key)
        }
      }
    }

    input: ColumnLayout {
      spacing: Config.theme.spacing
      // A prompt taller than a line takes its height from the conversation, so the panel holds still.
      onImplicitHeightChanged: panel.inputExtra = implicitHeight - Metrics.line

      // Escape clears it with the text.
      Thumbnail {
        Layout.leftMargin: Metrics.line + Config.theme.spacing
        path: panel.plugin.image
      }

      Prompt {
        id: prompt
        Layout.fillWidth: true
        glyph: panel.plugin.settings.promptGlyph || Glyphs.prompt
        // Until a turn says what Return does next, as the menu's input does.
        placeholder: panel.last ? Words.next(panel.last.phase, panel.last.kind, !panel.plugin.draft, panel.last.options.length) : panel.plugin.settings.placeholder.replace(/\{title\}/g, panel.plugin.title)
        active: panel.plugin.typing
        key: "Tab"
        onTapped: panel.plugin.focusPrompt()
        onBack: Panels.back()
        empty: text === "" && !panel.plugin.image
        detail: panel.plugin.imageRefused ? panel.plugin.words.noImages : ""
        onCleared: panel.plugin.clearImage()
        onTextChanged: panel.plugin.keepDraft(text)
        Component.onCompleted: set(panel.plugin.draft)

        // Shift+Return breaks the line; the rest go to the panel.
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

          // A failed prompt put back, or dropped with its conversation.
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
