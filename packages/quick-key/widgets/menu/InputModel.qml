import QtQuick
import qs.services

// A level's input and what it starts (docs/src/menu.md#input); the menu keeps which part has the keys.
QtObject {
  id: root

  required property MenuModel menu

  // { desc, cmd, plugin, context, after }: the focused island's (LevelModel.input); none where the layout shows no input.
  readonly property var input: menu.layout.includes("input") ? menu.focused.input : null
  // Without a `cmd`: its own plugin, else the one its level lists.
  readonly property var plugin: input && !input.cmd ? Plugins.get(input.plugin ?? menu.focused.level?.entry?.list ?? "") : null
  readonly property bool busy: plugin?.busy ?? false
  readonly property var turn: plugin?.turn ?? null
  // The text last sent, which a failed turn gives back to the input.
  property string lastSent: ""

  // By draftKey, kept as the menu closes and over a reload (Kept).
  readonly property var drafts: keptDrafts.value ?? ({})
  readonly property KeptValue keptDrafts: KeptValue {
    key: "drafts"
  }
  // The keys of the levels down to its own, a pin's as its level's, which a change to the input's label leaves be; "" without an input.
  readonly property string draftKey: !input ? "" : JSON.stringify(menu.focused === menu.body ? menu.levels.map(level => level.entry?.key ?? "") : [menu.focused.island])
  readonly property string draft: draftOf(draftKey)

  // The plugins the input showed while the menu stays on one level, whose leaving, or the menu closing, ends them all (Plugin.endVisit); the keys moving between islands end none.
  property var visiting: []
  readonly property string visit: menu.visit && JSON.stringify(menu.levels.map(level => level.entry?.key ?? level.kind))
  onVisitChanged: {
    for (const plugin of visiting) plugin.endVisit();
    visiting = [];
    join();
  }
  onPluginChanged: join()

  function join() {
    if (!visit || !plugin || visiting.includes(plugin)) return;
    visiting = visiting.concat([plugin]);
    plugin.startVisit();
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
