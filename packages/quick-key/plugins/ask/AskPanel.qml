pragma ComponentBehavior: Bound

import QtQuick
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
  // Escape clicked in the legend, for the prompt.
  signal escaped

  // The plugin's keys first, so any key closes its list of them.
  function handle(event) {
    const name = MenuKeys.name(event);
    // Held, C-y would answer the approval queued behind this one too.
    if (event.isAutoRepeat && plugin.keys.some(entry => entry.key === name)) return true;
    if (plugin.act(name)) return true;
    if (event.key !== Qt.Key_PageUp && event.key !== Qt.Key_PageDown) return false;
    paged(event.key === Qt.Key_PageDown);
    return true;
  }

  function keep(turn, selection) {
    if (selection) panel.selection = Object.assign({ turn: turn }, selection);
    else if (panel.selection && panel.selection.turn === turn) panel.selection = null;
  }

  component Turn: Exchange {
    id: turn
    required property int index
    // Its exchange's place in the conversation: the list runs from the newest up.
    readonly property int at: panel.plugin.exchanges.length - 1 - index
    readonly property var drawn: panel.plugin.describe(panel.plugin.exchanges[at] ?? ({}))
    maximumWidth: panel.threadWidth * 0.85
    question: drawn.question ?? ""
    text: drawn.text ?? ""
    phase: drawn.phase ?? "done"
    kind: drawn.kind ?? ""
    // The wait too, once noticeable.
    activity: Words.beside([drawn.activity, panel.plugin.waited >= 2 ? panel.plugin.waited + "s" : ""])
    table: !!drawn.table
    steps: drawn.steps ?? []
    copyable: true
    kept: panel.selection && panel.selection.turn === turn.at ? panel.selection : null
    onSelected: selection => panel.keep(turn.at, selection)
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

  Stack {
    shown: panel.plugin.shown
    namespace: panel.plugin.name
    width: Config.menu.width
    focus: "prompt"
    onKeyPressed: event => event.accepted = panel.handle(event)
    // Hidden, the conversation is kept.
    onDismissed: Panels.close()

    islands: [
      Island {
        name: "thread"
        cut: true
        content: ColumnLayout {
          // In the conversation's place and height, next to the prompt, as the menu's `?` lists its keys.
          Item {
            visible: panel.plugin.helping
            Layout.fillWidth: true
            Layout.preferredHeight: thread.Layout.preferredHeight

            KeyList {
              anchors.bottom: parent.bottom
              width: parent.width
              keys: panel.plugin.help
            }
          }

          Thread {
            id: thread
            visible: !panel.plugin.helping
            onWidthChanged: panel.threadWidth = width
            Component.onCompleted: panel.threadWidth = width
            Layout.fillWidth: true
            Layout.preferredHeight: Math.round(Math.min(panel.plugin.settings.lines * Metrics.line, (Window.height || Infinity) * 0.6) - panel.inputExtra)
            Layout.leftMargin: Metrics.itemPaddingX
            Layout.rightMargin: Metrics.itemPaddingX
            model: panel.plugin.exchanges.length
            delegate: Turn {
              width: thread.width
            }
            // Empty, it says only that it is being resumed or could not be.
            emptyTone: panel.plugin.failure ? "alert" : "dim"
            emptyText: panel.plugin.stage === "resuming" ? panel.plugin.words.resuming : panel.plugin.failure

            Connections {
              target: panel

              function onPaged(down) {
                thread.page(down);
              }
            }
          }
        }
      },
      Island {
        name: "prompt"
        padding: Config.theme.padding / 2
        // As a row's content is, so its key column lines up with the menu's keys.
        inset: Metrics.itemPaddingX
        content: Prompt {
          id: prompt
          // A prompt taller than a line takes its height from the conversation, so the panel holds still.
          onImplicitHeightChanged: panel.inputExtra = implicitHeight - Metrics.line
          glyph: panel.plugin.settings.promptGlyph || Glyphs.prompt
          // Until a turn says what Return does next, as the menu's input does.
          placeholder: panel.last ? Words.next(panel.last.phase) : panel.plugin.settings.placeholder.replace(/\{title\}/g, panel.plugin.title)
          onBack: Panels.back()
          onTextChanged: panel.plugin.keepDraft(text)
          Component.onCompleted: set(panel.plugin.draft)

          onKeyPressed: event => event.accepted = panel.handle(event)
          onSent: background => {
            if (!panel.plugin.send(text)) return;
            clear();
            if (background) Panels.close();
          }

          Connections {
            target: panel

            function onEscaped() {
              prompt.stepBack();
            }
          }

          Connections {
            target: panel.plugin

            // A failed prompt put back, selected so typing replaces it, or dropped with its conversation.
            function onDraftChanged() {
              if (prompt.text !== panel.plugin.draft) prompt.set(panel.plugin.draft, true);
            }
          }
        }
      },
      Island {
        name: "bar"
        split: Config.menu.islands
        padding: Config.theme.padding / 4
        // At least a padded line, as tall as the menu's bar.
        minimumHeight: Metrics.line + 2 * Metrics.itemPaddingY + Config.theme.padding / 2
        content: RowLayout {
          // With `menu.islands`, the legend and the top level's right slot each on an island of its own.
          readonly property var parts: [legend].concat(statuses.item ? [statuses.item] : [])

          // Only what the state changes.
          KeyLegend {
            id: legend
            keys: panel.plugin.keys.filter(entry => entry.shows() && !entry.hidden).map(entry => ({ key: entry.key, what: entry.what, clickable: true }))
              .concat(panel.plugin.draft ? [{ key: "Escape", what: Words.clear, clickable: true }] : [], MenuKeys.pick(panel.plugin.help, panel.plugin.settings.legend))
            onPicked: key => panel.plugin.act(key) || panel.escaped()
          }

          Item {
            Layout.fillWidth: true
          }

          Loader {
            id: statuses
            sourceComponent: Panels.statuses
          }
        }
      }
    ]
  }
}
