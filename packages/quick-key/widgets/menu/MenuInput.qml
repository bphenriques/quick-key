pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import qs
import qs.ui
import qs.ui.conversation

// The menu input island (InputModel): the last turn (Exchange) over the line to send; filtering, the line is the filter.
ColumnLayout {
  id: root

  required property MenuModel menu
  readonly property InputModel model: menu.input
  spacing: Config.theme.spacing / 2

  // A click opens the plugin's panel on the whole conversation.
  // The island holds the tallest turn of the visit (Island.holdKey), so it grows and never shrinks within it.
  ListItem {
    id: last
    // A turn it cannot hold opens the plugin's panel by itself, once, as its answer ends: while it streams in, its size is not known.
    readonly property bool expands: visible && exchange.overflows && root.model.turn !== root.model.expandedTurn && root.model.turn?.phase !== "working"
    visible: root.model.turn !== null && !root.menu.focused.filtering
    Layout.fillWidth: true
    // Outset by its padding, so the turn lines up with the prompt.
    Layout.leftMargin: -Metrics.itemPaddingX
    Layout.rightMargin: -Metrics.itemPaddingX
    onExpandsChanged: if (expands) settle.restart()
    verticalPadding: Metrics.itemPaddingY / 2
    onActivated: root.model.expand()

    // Decided once the turn is laid out, so a line cut only for a moment opens nothing, and outside the binding that noticed it.
    Timer {
      id: settle
      interval: 100
      onTriggered: if (last.expands) root.model.overflowed()
    }

    Exchange {
      id: exchange
      Layout.fillWidth: true
      lines: 3
      maximumWidth: root.width * 0.85
      question: root.model.turn?.question ?? ""
      text: root.model.turn?.text ?? ""
      phase: root.model.turn?.phase ?? "done"
      kind: root.model.turn?.kind ?? ""
      activity: root.model.turn?.activity ?? ""
      table: !!root.model.turn?.table
    }
  }

  Prompt {
    id: prompt
    Layout.fillWidth: true
    // Filtering, it is the filter: its glyph, its range on the right.
    readonly property bool filter: root.menu.focused.filtering
    focused: root.menu.inputFocused || filter
    // A turn shows its own spinner; without one (a chat running in the plugin's panel), the prompt does.
    busy: root.model.busy && root.model.turn === null && !filter
    key: filter ? "" : "Tab"
    glyph: filter ? Glyphs.search : Glyphs.prompt
    detail: filter ? root.menu.focused.filter.count : ""
    placeholder: filter ? Words.filterPrompt : root.model.turn ? Words.next(root.model.turn.phase) : root.model.input?.desc ?? ""
    // Focused, Escape while it clears, else its plugin's past conversations while it can list them.
    keys: filter || !root.menu.inputFocused ? []
      : text !== "" ? [{ key: "Escape", what: Words.clear, clickable: true }]
      : root.model.plugin?.recalls ? [{ key: "Ctrl+r", what: Words.history, clickable: true }] : []
    onPicked: key => key === "Ctrl+r" ? root.model.recall() : stepBack()
    maxLines: 1
    onTapped: root.menu.focusOn("input")
    onBack: root.menu.stepBack()
    // The level's own unsent text, as it opens or moves to another input; filtering, the filter's.
    readonly property string owner: root.model.draftKey
    onOwnerChanged: if (!filter) set(root.model.draftOf(owner))
    onFilterChanged: set(filter ? "" : root.model.draftOf(owner))
    Component.onCompleted: set(filter ? "" : root.model.draftOf(owner))
    onTextChanged: filter ? root.menu.focused.filter.search(text) : root.model.keepDraft(text)
    sends: !filter
    onSent: background => send(background)
    // Tab and Shift+Tab give the keys back to the body.
    onKeyPressed: event => {
      const name = MenuKeys.name(event);
      if (prompt.filter) {
        if (!root.menu.filterKey(name)) return;
      } else if (name === "Ctrl+r") {
        if (!root.model.recall()) return;
      } else if (name === "Tab" || name === "Backtab") root.menu.focusOn("body");
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

      function onEscaped() {
        prompt.stepBack();
      }
    }

    // A failed turn gives back what was sent, selected: Return retries it, typing replaces it.
    Connections {
      target: root.model.plugin

      function onTurnChanged() {
        if (root.model.plugin?.turn?.phase === "error" && prompt.text === "") prompt.set(root.model.lastSent, true);
      }
    }
  }
}
