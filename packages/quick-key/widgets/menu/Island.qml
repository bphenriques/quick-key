pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.ui

// The menu's input island (InputModel): the conversation's last turn (Exchange, drawn by its phase) over the line to send; Return sends it and keeps the focus for the next, Ctrl+Shift+Return sends it in the background. Filtering, the line is the filter.
GridLayout {
  id: root

  required property MenuModel menu
  readonly property InputModel model: menu.island
  // The prompt sits nearest the screen's edge, the turn beyond it: at the top edge (Config.atTop), the order flips.

  columns: 1
  rowSpacing: Config.theme.spacing / 2

  // Lit while Tab has it; a click, or Return then, opens the plugin's panel on the whole conversation.
  ListItem {
    id: last
    // The tallest turn of the visit, which the island keeps so it grows and never shrinks within it.
    property real tallest: 0
    // A turn it cannot hold opens the plugin's panel by itself, once, as its answer ends: while it streams in, its size is not known.
    readonly property bool expands: visible && exchange.overflows && root.model.turn !== root.model.expandedTurn && root.model.turn?.phase !== "working"
    visible: root.model.turn !== null && !root.menu.filtering
    Layout.fillWidth: true
    Layout.row: Config.atTop ? 1 : 0
    // The height held sits beyond it, outside what Tab lights, so the turn stays next to the prompt.
    Layout.topMargin: Config.atTop ? 0 : Math.max(0, last.tallest - exchange.implicitHeight)
    Layout.bottomMargin: Config.atTop ? Math.max(0, last.tallest - exchange.implicitHeight) : 0
    // Outset by its padding, so the turn lines up with the prompt.
    Layout.leftMargin: -Config.theme.itemPaddingX
    Layout.rightMargin: -Config.theme.itemPaddingX
    onVisibleChanged: if (!visible) last.tallest = 0
    onExpandsChanged: if (expands) settle.restart()
    verticalPadding: Config.theme.itemPaddingY / 2
    current: root.menu.answerFocused
    onActivated: root.model.expand()

    // Decided once the turn is laid out, so a line cut only for a moment opens nothing, and outside the binding that noticed it.
    Timer {
      id: settle
      interval: 100
      onTriggered: if (last.expands) root.model.overflowed()
    }

    // Held once laid out, so a height the text has only for a moment, before it has its width, is not kept.
    Timer {
      id: latch
      interval: 100
      onTriggered: last.tallest = Math.max(last.tallest, exchange.implicitHeight)
    }

    Exchange {
      id: exchange
      Layout.fillWidth: true
      onImplicitHeightChanged: latch.restart()
      lines: 3
      maximumWidth: root.width * 0.85
      question: root.model.turn?.question ?? ""
      context: root.model.turn?.context ?? ""
      text: root.model.turn?.text ?? ""
      phase: root.model.turn?.phase ?? "done"
      kind: root.model.turn?.kind ?? ""
      activity: root.model.turn?.activity ?? ""
      options: root.model.choices
      table: !!root.model.turn?.table
      picking: root.model.turn?.kind === "question" && fits
    }
  }

  Prompt {
    id: prompt
    Layout.fillWidth: true
    Layout.row: Config.atTop ? 0 : 1
    // Filtering, it is the filter: its glyph, its range on the right.
    readonly property bool filter: root.menu.filtering
    active: root.menu.inputFocused || filter
    // A turn shows its own spinner; without one (a chat running in the plugin's panel), the prompt does.
    busy: root.model.busy && root.model.turn === null && !filter
    key: filter ? "" : "Tab"
    glyph: filter ? Glyphs.search : Glyphs.prompt
    detail: filter ? root.menu.filter.count : ""
    placeholder: filter ? Words.filterPrompt : root.model.turn ? exchange.next : root.model.input?.desc ?? ""
    // The turn's own keys while Tab has it; focused, Escape while it clears, else, before a conversation starts, its plugin's past ones.
    keys: root.menu.answerFocused ? [{ key: "Return", what: Words.open, clickable: true }, { key: "y", what: Words.copy, clickable: true }]
      : filter || !root.menu.inputFocused ? []
      : text !== "" ? [{ key: "Escape", what: Words.clear, clickable: true }]
      : !root.model.turn && root.model.plugin?.recalls ? [{ key: "Ctrl+r", what: Words.history, clickable: true }] : []
    onPicked: key => key === "Ctrl+r" ? root.model.recall() : key === "Escape" ? stepBack() : root.model.answerKey(key)
    maxLines: 1
    onTapped: root.menu.inputFocused = true
    onBack: root.menu.stepBack()
    // The level's own unsent text, as it opens or moves to another input; filtering, the filter's.
    readonly property var owner: root.model.input
    onOwnerChanged: if (!filter) set(root.model.draftOf(owner))
    onFilterChanged: set(filter ? "" : root.model.draftOf(owner))
    Component.onCompleted: set(filter ? "" : root.model.draftOf(owner))
    onTextChanged: filter ? root.menu.filter.query = text : root.model.keepDraft(text)
    // Tab moves on to the turn, else to the body as Shift+Tab does; while the line is empty, a waiting choice takes the digits.
    onKeyPressed: event => {
      const send = MenuKeys.sends(event);
      const name = MenuKeys.name(event);
      // A choice waiting takes the digits whether or not they all show here, so they never type.
      const waiting = !prompt.filter && root.model.turn?.kind === "question" && prompt.text === "";
      if (prompt.filter) {
        if (!root.menu.filterKey(name)) return;
      } else if (send) prompt.send(send === "background");
      else if (waiting && /^[1-9]$/.test(name)) {
        if (exchange.picking) root.model.pick(Number(name) - 1);
      } else if (name === "Ctrl+r") {
        if (!root.model.recall()) return;
      } else if (name === "Tab" && last.visible) {
        root.menu.inputFocused = false;
        root.menu.answerFocused = true;
      } else if (name === "Tab" || name === "Backtab") root.menu.inputFocused = false;
      else return;
      event.accepted = true;
    }

    function send(background) {
      // Cleared first: sending may close the menu, and the prompt with it.
      const text = prompt.text;
      prompt.clear();
      if (!root.model.submit(text, background)) prompt.set(text);
    }

    Connections {
      target: root.model

      function onPicked(key) {
        if (key === "Escape") prompt.stepBack();
        else prompt.send(true);
      }
    }

    // A failed turn gives back what was sent, so Return retries it.
    Connections {
      target: root.model.plugin

      function onTurnChanged() {
        if (root.model.plugin.turn?.phase === "error" && prompt.text === "") prompt.set(root.model.lastSent);
      }
    }
  }
}
