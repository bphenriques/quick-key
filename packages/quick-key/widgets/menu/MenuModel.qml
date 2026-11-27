import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.builtins
import "keymap.js" as Keymap

Scope {
  id: root

  // Under a plugin panel it keeps its levels and visit; leaving the stack resets them.
  readonly property bool open: Panels.top === root
  readonly property bool inStack: Panels.owners.includes(root)
  onInStackChanged: if (!inStack) reset()
  onOpenChanged: input.settle()
  // Levels past the top one: an entry ("entry"), an app menu ("menu") or an item menu ("actions"), each keeping the island, input and bar stop it was opened from for Escape to restore.
  property var levels: []
  // How deep a shortcut or key path opened it: Escape closes there.
  property int base: 0
  // "Ctrl" or "Super" held a second (so a chord does not flash them), or "Help" after `?`.
  readonly property string held: internal.held
  readonly property bool inputFocused: internal.focus === "input"

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  // The deepest open level whose entry sets a layout, null for menu.layout's: a level without one opens in its body.
  readonly property var home: levels.filter(level => Config.kind(level.entry?.layout) === "list").pop() ?? null
  readonly property var homeLayout: layoutOf(home)
  // A pinned level shows on the level declaring it only, stepping aside on those opened from it.
  readonly property var layout: level === home ? homeLayout : homeLayout.filter(name => ["input", "body", "bar"].includes(name))
  // The keys of the entries the layout pins, on the level declaring it.
  readonly property var pinnedKeys: pinsOf(layout)
  // While the menu shows the declaring level's layout, which a pinned level never shrinks within; the input's visit is a level's within it (InputModel.settle).
  readonly property string visit: inStack ? JSON.stringify(homeLayout) : ""
  readonly property var level: levels[levels.length - 1] ?? null
  // The level the body shows.
  readonly property LevelModel body: LevelModel {
    menu: root
    level: root.level
  }
  // The island with the keys: the body, or a pinned level; one leaving the layout gives them back to the body.
  readonly property LevelModel focused: modelOf(internal.island) ?? body
  // The cursor stands on that island's bar, its keys acting as ever; an arrow past the island above, a click or Escape back from a level opened there put it there.
  readonly property bool cursorOnBar: internal.cursorOnBar && bar.stops.length > 0
  // What the arrows and Return act on: the bar, or the island with the cursor.
  readonly property var cursorAt: cursorOnBar ? bar : focused
  // The pinned levels showing, which the menu draws.
  readonly property var pinnedLevels: Array.from(pinnedModels.instances).filter(model => pinnedKeys.includes(model.island))
  // What the shown islands list, for a list that works while shown (Lists.scanning).
  readonly property var lists: [body].concat(pinnedLevels).map(model => model.level?.entry?.list ?? "")
  readonly property InputModel input: InputModel {
    menu: root
  }
  readonly property BarModel bar: BarModel {
    menu: root
  }
  // Nothing for the input to show: it then shows empty, unless at either end (Places.shown).
  readonly property bool inputEmpty: input.input === null && !focused.filtering
  // The level islands on screen, top to bottom, and those with an input it shows.
  readonly property var shown: layout.map(name => modelOf(name)).filter(model => model)
  readonly property var inputs: layout.includes("input") ? shown.filter(model => model.input).map(model => model.island) : []
  // What holding Ctrl or Super lists: the bar's keys, and its compositor shortcuts.
  readonly property var holds: ({
      Ctrl: bar.keyed.filter(item => item.key).map(item => bar.hint(item, MenuKeys.names(item.key).map(name => "Ctrl+" + name))),
      Super: bar.keyed.filter(item => bar.shortcutOf(item)).map(item => bar.hint(item, bar.shortcutOf(item)))
    })
  // The keys on screen, one map (keymap.js): every island's at rest, the input's while typing, the filter's while filtering, any key closing `?`'s list.
  readonly property var rest: Keymap.rest({ islands: shown.map(islandOf).concat([{ name: bar.island, focused: cursorOnBar, free: bar.cursor.free, cursorItem: bar.cursorItem }]), bar: bar.keyed, holds: { Ctrl: holds.Ctrl.length > 0, Super: holds.Super.length > 0 }, tab: inputs.length > 0, words: Words })
  readonly property var typing: Keymap.typing({ tab: input.input !== null, recalls: !!input.plugin?.recalls, bar: bar.keyed, words: Words })
  readonly property var bindings: held === "Help" ? Keymap.helping() : focused.filtering ? Keymap.filtering({ island: focused.island, rows: focused.filter.rows, item: focused.filter.item, size: focused.filter.size, bar: bar.keyed })
    : inputFocused ? typing : rest
  // Keys no row shows, where they act: at rest, then in the input.
  readonly property var help: Keymap.help(rest.filter(binding => binding.what !== "back").concat(typing))
  readonly property var hints: held === "Help" ? help : holds[held] ?? []

  // Whether a key reaches the island or the menu itself (`?`, ESC, TAB), not another island: a view's RET is its own only while it has the cursor.
  function owns(model, key) {
    const island = Keymap.route(rest, MenuKeys.names(key)[0])?.island ?? "";
    return island === "" || island === model.island;
  }

  // An island as the key map reads it.
  function islandOf(model) {
    return {
      name: model.island,
      items: model.items,
      pins: model === body ? pinnedLevels.map(pin => ({ key: pin.island, desc: pin.level.entry.desc })) : [],
      view: model.viewModel?.keys ?? [],
      more: model.more,
      filters: model.slashFilters,
      focused: model.focused,
      barShows: model === focused,
      free: model.cursor.free,
      content: model.content,
      cursorItem: model.cursorItem
    };
  }

  // What each kind of binding does, given it, the key's name and the island holding it; false when it did nothing.
  readonly property var handlers: ({
      help: () => hold("Help"),
      closeHelp: () => hold(""),
      back: () => stepBack(),
      view: (binding, name, model) => model.viewModel.handleKey(name),
      row: (binding, name, model) => activate(binding.item, name, model),
      pin: binding => focusIsland(binding.key),
      more: (binding, name, model) => pickList(model.level.entry.list, model.level.entry.hide, model.level.entry.pins),
      // Typed in the input, which shows the cursor island's.
      filter: (binding, name, model) => {
        focusIsland(model.island);
        model.startFilter();
      },
      itemMenu: binding => openMenu(binding.item),
      bar: binding => activate(binding.item, binding.name, body),
      // The cursor's keys, on the bar too: what Return runs acts on the island with the cursor's level.
      cursor: (binding, name) => cross(name) || cursorAt.cursor.key(name),
      return: binding => !!binding.item && activate(binding.item, binding.item.key, focused) !== false,
      choose: binding => choose(binding.item),
      move: (binding, name, model) => model.filter.move(binding.by),
      tab: binding => tab(binding.step),
      recall: () => input.recall(),
      send: () => false,
      hold: () => false
    })

  // A key by its name, as typing it would; a key path's never moves or runs the cursor (`withCursor` false), so a binding never drifts from what it shows.
  function dispatch(name, withCursor = true) {
    const binding = Keymap.route(bindings, name);
    if (!binding || binding.cursor && !withCursor) return false;
    return handlers[binding.what](binding, name, modelOf(binding.island) ?? body) !== false;
  }

  // A level's entries: the top's, or an entry's submenu.
  function entriesAt(at) {
    return at ? Array.from(at.entry.submenu ?? []) : entries;
  }

  // The islands by name, top to bottom, each once, a pinned level by the key of an entry with a level on its own (Validation names what else is wrong).
  function layoutOf(at) {
    return Array.from(at ? at.entry.layout : Config.menu.layout)
      .map(part => typeof part === "string" ? part : entriesAt(at).some(entry => entry.key === part?.level && (entry.submenu || entry.list || entry.view)) ? part.level : "")
      .filter((name, index, all) => name && all.indexOf(name) === index);
  }

  function pinsOf(layout) {
    return layout.filter(name => !["input", "body", "bar"].includes(name));
  }

  // An island's level by its name: the body's, or a pinned level's.
  function modelOf(name) {
    return name === "body" ? body : pinnedLevels.find(model => model.island === name) ?? null;
  }

  // A pinned level, kept by its key while the level declaring it is open, so it comes back as it was; a reload, or another layout pinning that key, gives it its entry anew.
  Variants {
    id: pinnedModels
    model: root.pinsOf(root.homeLayout)

    LevelModel {
      required property string modelData
      readonly property var entry: root.entriesAt(root.home).find(entry => entry.key === modelData) ?? ({})
      menu: root
      island: modelData
      level: ({ kind: "entry", entry: entry, width: entry.width })
      limit: entry.limit ?? 9
    }
  }

  function keyChars(group) {
    return Math.max(1, ...group.map(item => MenuKeys.label(item.key, item.paired).length));
  }

  function show() {
    // Sources without change events are read as the menu opens.
    Compositor.refresh();
    Config.refresh();
    Plugins.refresh();
    Daemons.refresh();
    Panels.open(root);
    input.settle();
  }

  function toggle() {
    if (open) hide();
    else show();
  }

  // By its key in the top level's key map, a row, a pinned level or the bar's (without Ctrl), as a compositor shortcut opens it; a pinned level takes the cursor.
  function toggleEntry(key) {
    // The top level's pinned levels, whichever layout shows.
    const pins = pinsOf(layoutOf(null));
    const rows = entries.filter(entry => !pins.includes(entry.key)).map(entry => body.itemOf(entry));
    const top = Keymap.rest({ islands: [{ name: "body", items: rows, pins: pins.map(key => ({ key })) }], bar: bar.itemsOf(bar.slotsOf(bar.top)) });
    const binding = [key, "Ctrl+" + key].map(name => Keymap.route(top, name)).find(binding => ["row", "pin", "bar"].includes(binding?.what));
    if (!binding) return;
    const pin = binding.what === "pin";
    // A bar list's item has no entry to toggle: it runs.
    if (pin ? open && !home && focused.island === key : binding.item.entry && level?.entry === binding.item.entry) {
      hide();
      return;
    }
    levels = [];
    if (!open) show();
    focusIsland(pin ? key : "body");
    if (!pin) activate(binding.item, key, body);
    base = levels.length;
  }

  // "body" or "input": the input, or the island it shows the input of.
  function focusOn(where) {
    if (where === "input" && !inputFocused) internal.tabFrom = focused.island;
    internal.focus = where;
    internal.cursorOnBar = false;
  }

  // ↑↓ past the cursor's first or last row cross onto the nearest row of the island above or below, or the bar's nearest stop, where it leaves that arrow free too: never into an input or a view, which leave none.
  function cross(name) {
    const places = layout.map(island => island === bar.island ? bar : modelOf(island)).filter(place => place);
    const next = places[places.indexOf(cursorAt) + (name === "Down" ? 1 : -1)];
    if (!next?.cursor.free.includes(name) || !cursorAt.cursor.atEdge(name)) return false;
    // The bar is the bar of the island with the cursor, which keeps it.
    if (next === bar) internal.cursorOnBar = true;
    else focusIsland(next.island);
    next.cursor.point(next.cursor.ids[name === "Down" ? 0 : next.cursor.ids.length - 1]);
    return true;
  }

  // TAB's round: the input of the island whose rows it left, then each other input on screen top to bottom, then those rows; S-TAB (step -1) the reverse.
  function tab(step) {
    const from = inputFocused && modelOf(internal.tabFrom) ? internal.tabFrom : focused.island;
    const stops = [""].concat(inputs.filter(name => name === from), inputs.filter(name => name !== from));
    const next = stops[(stops.indexOf(inputFocused ? focused.island : "") + step + stops.length) % stops.length];
    focusIsland(next || from);
    internal.focus = next ? "input" : "body";
    internal.tabFrom = from;
  }

  // The island by its name takes the keys from the input and the island that had them, whose filter stops.
  function focusIsland(name) {
    if (name !== focused.island) {
      focused.stopFilter();
      internal.focus = "body";
    }
    internal.island = name;
    internal.cursorOnBar = false;
    input.settle();
  }

  // A click on a bar item runs it as its RET would, the cursor standing on it.
  function clickBar(item) {
    focused.stopFilter();
    internal.focus = "body";
    internal.cursorOnBar = true;
    bar.cursor.point(String(item.uid));
    activate(item, item.key, body);
  }

  // A click on a row runs it, its island taking the keys.
  function click(item, from) {
    focusIsland(from.island);
    activate(item, undefined, from);
  }

  // A right click opens its own menu, its island taking the keys first, so stepping back returns to it.
  function secondaryClick(item, from) {
    focusIsland(from.island);
    openMenu(item);
  }

  function hold(modifier) {
    internal.held = modifier;
  }

  function hide() {
    Panels.close();
    reset();
  }

  function reset() {
    levels = [];
    base = 0;
    for (const model of [body].concat(pinnedLevels)) {
      model.stopFilter();
      model.cursor.point(undefined);
    }
    bar.cursor.point(undefined);
    internal.held = "";
    internal.focus = "body";
    internal.island = "body";
    internal.cursorOnBar = false;
    input.settle();
  }

  // The island it was opened from takes the keys again, the body if the layout no longer shows it, and the cursor the bar's stop it stood on.
  function back() {
    const left = level;
    levels = levels.slice(0, -1);
    body.stopFilter();
    internal.island = modelOf(left?.island) ? left.island : "body";
    internal.focus = left?.inputFocused ? "input" : "body";
    internal.cursorOnBar = !!left?.cursorOnBar;
    bar.cursor.point(left?.barAt);
    body.cursor.point(left?.cursor);
    body.clearViews();
    input.settle();
  }

  // Opened from any island, a level shows in the body.
  function push(next) {
    levels = levels.concat([Object.assign({}, next, { inputFocused: inputFocused, island: focused.island, cursor: body.cursor.current, cursorOnBar: cursorOnBar, barAt: bar.cursor.current })]);
    focused.stopFilter();
    body.stopFilter();
    internal.island = "body";
    internal.focus = "body";
    internal.cursorOnBar = false;
    body.cursor.point(undefined);
    body.clearViews();
    input.settle();
  }

  function find(candidates, name) {
    return candidates.find(item => MenuKeys.matches(item.key, name));
  }

  // A click on a pair runs nothing; an action keeps the menu open unless it `closes` it. `from` is the island whose level it acts on.
  function run(entry, name, from = focused) {
    const action = from.actionOf(entry);
    if (action) {
      const second = MenuKeys.names(entry.key).indexOf(name);
      if (action.pair && second < 0) return;
      // Read before hide(), which leaves the level.
      const list = from.levelList;
      if (action.closes) hide();
      internal.ran = entry;
      action.run(second === 1, list, root);
      return;
    }
    const cmd = MenuKeys.isPair(entry) ? Array.from(entry.cmd)[MenuKeys.names(entry.key).indexOf(name)] : entry.cmd;
    // No command: an entry showing a plugin activates it, as a click on it in a bar does.
    if (!cmd) {
      internal.ran = entry;
      return Plugins.get(entry.status ?? "")?.activate();
    }
    if (!entry.keepOpen) hide();
    Commands.run(cmd);
  }

  // Over a plugin panel it is the only level, so Escape shows the panel again.
  function pickList(list, hide, pins) {
    const over = !open;
    if (over) Panels.remove(root);
    if (!open) show();
    push({ kind: "entry", entry: { list: list, hide: hide, pins: pins }, picking: true, width: Config.menu.width });
    if (over) base = levels.length;
    body.filterSlots = 9;
  }

  // Escape once the input is cleared: an input or the bar gives the keys back to its island first, as a card's reply does, and a pinned level to the body.
  function stepBack() {
    if (focused.filtering && !focused.level.picking) return focused.stopFilter();
    if (inputFocused) return focusOn("body");
    if (cursorOnBar) return focusIsland(focused.island);
    if (focused.viewModel && focused.viewModel.stepBack()) return;
    if (focused !== body) return focusIsland("body");
    if (levels.length <= base) Panels.back();
    else back();
  }

  function choose(item) {
    if (!item) return;
    focused.filter.point(item.id);
    activate(item, item.key);
  }

  // Whether activating an item does anything: a name only shows, unless it is a plugin's, by name or an entry's status.
  function runs(item) {
    const entry = item.entry;
    return !!(item.select || Plugins.get(item.status ?? "") || entry && (entry.cmd || entry.action || entry.submenu || entry.list || entry.view));
  }

  function activate(item, name, from = focused) {
    if (item.enabled === false) return;
    // A tray app that only offers a menu does nothing when activated (Quickshell's onlyMenu).
    if (item.app?.onlyMenu) return openMenu(item);
    if (item.select) {
      if (item.closes) hide();
      internal.ran = item;
      item.select();
    } else if (!item.entry) {
      internal.ran = item;
      Plugins.get(item.status)?.activate();
    } else if (item.entry.submenu || item.entry.list || item.entry.view) {
      const next = body.viewModelOf(item.entry.view);
      if (next) next.reset();
      push({ kind: "entry", entry: item.entry, width: item.entry.width });
    } else {
      run(item.entry, name, from);
    }
  }

  // Alt with its digit, or a right click; in the body, as wide as what it shows.
  function openMenu(item) {
    if (item?.actions?.length > 0) push({ kind: "actions", title: item.desc, icon: item.icon ?? "", actions: item.actions, width: body.width });
    else if (item?.app?.hasMenu) push({ kind: "menu", title: item.desc, image: item.image ?? "", handle: item.app.menu, width: body.width });
  }

  // The wheel, up as a pair's second key (more): a listed item adjusts itself, a pair steps, a row opening a level steps the pair its status adjusts.
  function act(item, up, from = focused) {
    if (item.adjust) return item.adjust(up);
    const adjust = Statuses.of(item.status ?? "").adjust;
    const pair = item.entry?.submenu ? Array.from(item.entry.submenu).find(entry => adjust && entry.action === adjust) : item.paired ? item.entry : null;
    if (pair && from.available(pair)) run(pair, MenuKeys.names(pair.key)[up ? 1 : 0], from);
  }

  // Escape and Tab are kept free by Validation.
  function handleKey(event) {
    // A bare modifier has no name, and Super belongs to the compositor.
    if (event.modifiers & Qt.MetaModifier) return false;
    // A held key repeats on the level it was pressed on, never into the one it opened.
    if (event.isAutoRepeat && level !== internal.pressedOn) return true;
    if (!event.isAutoRepeat) internal.pressedOn = level;
    const name = MenuKeys.name(event);
    // Held, a row acts once, as Return does on the cursor's; a pair steps on.
    const item = event.isAutoRepeat ? Keymap.route(bindings, name)?.item : null;
    if (item && !item.paired) return true;
    return dispatch(name);
  }

  // A key path (`a 2`, `t Ctrl+x`) run from the top level at rest as typing it would, the same through a pinned level: what a binding reaches.
  function press(path) {
    const closed = !open;
    reset();
    if (!open) show();
    for (const [i, name] of path.trim().split(/\s+/).entries()) {
      // A key that closed the menu ends the path, so none past it opens a level on the closed menu.
      if (i > 0 && !inStack) return false;
      internal.ran = null;
      if (!dispatch(name, false)) return false;
    }
    base = levels.length;
    // Opened for the path, the menu closes after the action it ends on, unless that opened a picker or another surface.
    if (closed && internal.ran && !internal.ran.keepOpen && open && !focused.filtering) hide();
    return true;
  }

  // The key paths `press` takes, as Markdown.
  function keyMap() {
    const lines = [];
    const path = (prefix, key) => MenuKeys.names(key).map(name => "`" + (prefix + " " + name).trim() + "`").join(" ");
    // A bar's entries, on Ctrl in the level they sit on: a list without a key on its digits, the rest on 0.
    const bar = (slots, prefix, depth) => {
      for (const slot of ["left", "center", "right"]) {
        for (const part of Array.from(slots?.[slot] ?? [])) {
          if (typeof part === "string" || !part.key && !part.list) continue;
          const shown = Math.min(part.limit ?? 9, 9);
          const names = part.key ? MenuKeys.names(part.key) : [shown > 1 ? "1-" + shown : "1", "0"];
          const keys = names.map(name => "`" + (prefix + " Ctrl+" + name).trim() + "`").join(" ");
          lines.push("  ".repeat(depth) + "- " + keys + " " + (part.desc ?? part.status ?? ""));
        }
      }
    };
    const walk = (entries, prefix, depth) => {
      for (const entry of Array.from(entries ?? [])) {
        const at = (prefix + " " + MenuKeys.names(entry.key ?? "")[0]).trim();
        lines.push("  ".repeat(depth) + "- " + path(prefix, entry.key ?? "") + " " + (entry.desc ?? entry.status ?? ""));
        for (const [i, pin] of Array.from(entry.pins ?? []).entries()) lines.push("  ".repeat(depth + 1) + "- `" + at + " " + (i + 1) + "` " + pin.label);
        if (entry.list) lines.push("  ".repeat(depth + 1) + "- `" + at + " 1-9` " + entry.list);
        walk(entry.submenu, at, depth + 1);
        bar(entry.bar, at, depth + 1);
      }
    };
    walk(entries, "", 0);
    bar(root.bar.top, "", 0);
    return lines.join("\n");
  }

  // A bar left with nothing to stop on gives the cursor back, so a stop coming back later takes no keys.
  Connections {
    target: root.bar

    function onStopsChanged() {
      if (root.bar.stops.length === 0) internal.cursorOnBar = false;
    }
  }

  Connections {
    target: Picker

    function onRequested(list) {
      root.pickList(list);
    }
  }

  QtObject {
    id: internal
    property string held: ""
    property string focus: "body"
    // The island with the cursor, by name.
    property string island: "body"
    // Whether the cursor stands on that island's bar.
    property bool cursorOnBar: false
    property var pressedOn: null
    // The island whose rows TAB left, which it comes back to.
    property string tabFrom: "body"
    // The entry or item whose action the last key ran.
    property var ran: null
  }
}
