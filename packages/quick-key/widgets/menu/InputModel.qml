import QtQuick
import qs
import qs.services

// A level's input and what it starts (docs/src/menu.md#input); the menu keeps which part has the keys.
QtObject {
  id: root

  required property MenuModel menu

  // { desc, cmd, plugin, context, after }: an entry's `input`, or `menu.input` at the top level.
  readonly property var input: menu.level === null ? Config.menu.input ?? null : menu.level.entry?.input ?? null
  // Without a `cmd`: its own plugin, else the one the level lists.
  readonly property var plugin: input && !input.cmd ? Plugins.get(input.plugin ?? menu.level?.entry?.list ?? "") : null
  readonly property bool busy: plugin?.busy ?? false
  readonly property var turn: plugin?.turn ?? null
  // The text last sent, which a failed turn gives back to the input.
  property string lastSent: ""

  // By draftKey, kept as the menu closes and over a reload (Kept).
  readonly property var drafts: keptDrafts.value ?? ({})
  readonly property KeptValue keptDrafts: KeptValue {
    key: "drafts"
  }
  // The keys of the levels down to its own, which a change to the input's label leaves be; "" without an input.
  readonly property string draftKey: input ? JSON.stringify(menu.levels.map(level => level.entry?.key ?? "")) : ""
  readonly property string draft: draftOf(draftKey)

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

  // ESC clicked in the bar's legend while filtering, for the prompt to step back as the key does.
  signal escaped

  // True when taken; the input keeps the text if not.
  function submit(text, background) {
    text = text.trim();
    if (!text || !input || busy) return false;
    if (input.cmd) Commands.runThen(input.cmd, input.after ?? "", text);
    // A plugin that failed to load takes nothing.
    else if (!plugin || plugin.submit(text, input.after ?? "", input.context ?? "") === false) return false;
    lastSent = text;
    if (background) menu.hide();
    return true;
  }

  function recall() {
    return !!plugin?.recall();
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

  function draftOf(key) {
    return key ? drafts[key] ?? "" : "";
  }

  function keepDraft(text) {
    if (draftKey && text !== draft) Kept.set("drafts", Object.assign({}, drafts, { [draftKey]: text }));
  }
}
