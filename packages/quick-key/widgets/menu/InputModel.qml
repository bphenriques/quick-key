import QtQuick
import Quickshell
import qs
import qs.services

// A level's input and what it starts (docs/src/menu.md#input): the text it takes, where that goes, the turn it answers with, its drafts and the visit; the menu keeps which of its parts has the keys.
QtObject {
  id: root

  required property MenuModel menu

  // The text a level takes under its body (an entry's `input`, or `menu.input` at the top level): { desc, cmd, plugin, format, after }.
  readonly property var input: menu.level === null ? Config.menu.input ?? null : menu.level.entry?.input ?? null
  // The plugin an input without a `cmd` gives its text: its own, else the one the level lists.
  readonly property var plugin: input && !input.cmd ? Plugins.get(input.plugin ?? menu.level?.entry?.list ?? "") : null
  readonly property bool busy: plugin?.busy ?? false
  // The turn of the conversation the input started (Plugin.turn), its options a digit picks.
  readonly property var turn: plugin?.turn ?? null
  readonly property var choices: turn?.options ?? []
  onTurnChanged: if (!turn && menu.answerFocused) menu.focusOn("body")
  // The text last sent, which a failed turn gives back to the input.
  property string lastSent: ""

  // Each input's unsent text, by the input, kept as the menu closes and over a reload (Kept), as Ask keeps its draft.
  readonly property var drafts: keptDrafts.value ?? ({})
  readonly property KeptValue keptDrafts: KeptValue {
    key: "drafts"
  }
  readonly property string draft: draftOf(input)

  // The plugin a visit is with, while the menu, in Panels' stack, shows its input: a change of the plugin or the input, or the menu leaving the stack, ends it (Plugin.endVisit).
  readonly property string visit: menu.inStack && plugin ? plugin.name + "\n" + JSON.stringify(input) : ""
  property var visiting: null
  onVisitChanged: {
    if (visiting) visiting.endVisit();
    visiting = visit ? plugin : null;
    if (visiting) visiting.startVisit();
  }

  // A turn the island cannot hold opens the plugin's panel by itself, as a popup does: once, so coming back does not open it again.
  property var expandedTurn: null

  // A key of the input's, clicked in the bar's legend (Escape's step, a send in the background), for the prompt.
  signal picked(var key)

  // The input's text, to its command as $1, else its plugin; whether it was taken, so the input keeps it if not.
  function submit(text, background) {
    text = text.trim();
    if (!text || !input || busy) return false;
    // The format wraps what starts a conversation; once the plugin has answered, the next send answers it as typed.
    const sent = input.format && (!turn || turn.phase === "error") ? input.format.replace(/\{text\}/g, () => text) : text;
    if (input.cmd) Commands.runThen(input.cmd, input.after ?? "", sent);
    // A plugin that failed to load takes nothing.
    else if (!plugin || plugin.submit(sent, background, input.after ?? "") === false) return false;
    lastSent = text;
    if (background) menu.hide();
    return true;
  }

  // The plugin's past conversations (C-r), on a level over this one; whether it has any to show.
  function recall() {
    return !!plugin?.recall();
  }

  // An option of the answer, sent as the next message.
  function pick(index) {
    const option = choices[index];
    return option !== undefined && submit(option, false);
  }

  // The plugin's own panel on the conversation, over the menu: stepping back from it shows this level again with its input focused, the visit going on.
  function expand() {
    menu.focusOn("input");
    plugin?.expand();
  }

  function overflowed() {
    if (turn === expandedTurn || turn?.phase === "working") return;
    expandedTurn = turn;
    expand();
  }

  // Keys while the answer has them: Return opens the plugin's panel, y copies the answer, Tab gives them to the body, Shift+Tab back to the input.
  function answerKey(name) {
    if (name === "Return") expand();
    else if (name === "y") Quickshell.clipboardText = turn?.text ?? "";
    else if (name === "Tab") menu.focusOn("body");
    else if (name === "Backtab") menu.focusOn("input");
    else return false;
    return true;
  }

  function draftOf(of) {
    return of ? drafts[JSON.stringify(of)] ?? "" : "";
  }

  function keepDraft(text) {
    if (input && text !== draft) Kept.set("drafts", Object.assign({}, drafts, { [JSON.stringify(input)]: text }));
  }
}
