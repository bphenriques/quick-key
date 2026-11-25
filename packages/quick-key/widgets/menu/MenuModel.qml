import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.builtins

Scope {
  id: root

  // Under a plugin panel it keeps its levels and visit; leaving the stack resets them.
  readonly property bool open: Panels.top === root
  readonly property bool inStack: Panels.owners.includes(root)
  onInStackChanged: if (!inStack) reset()
  // Levels past the top one: an entry ("entry"), an app menu ("menu") or an item menu ("actions"), each keeping inputFocused for Escape to restore.
  property var levels: []
  // How deep a shortcut or key path opened it: Escape closes there.
  property int base: 0
  // "Ctrl" or "Super" held a second (so a chord does not flash them), or "Help" after `?`.
  readonly property string held: internal.held
  readonly property bool inputFocused: internal.focus === "input"

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  readonly property var level: levels[levels.length - 1] ?? null
  // The level the body shows, whose state the views and keys read through the menu.
  readonly property LevelModel body: LevelModel {
    menu: root
    level: root.level
  }
  readonly property var viewModel: body.viewModel
  readonly property var view: body.view
  readonly property InputModel input: InputModel {
    menu: root
  }
  readonly property bool filtering: body.filtering
  readonly property int filterSlots: body.filterSlots
  readonly property ListFilter filter: body.filter
  readonly property var items: body.items
  readonly property bool content: body.content
  readonly property var bodyActions: body.bodyActions
  readonly property var barActions: body.barActions
  readonly property var rows: body.rows
  readonly property Cursor cursor: body.cursor
  readonly property var cursorItem: body.cursorItem
  readonly property int width: body.width
  readonly property int columns: body.columns
  readonly property string emptyText: body.emptyText
  readonly property var topBar: ({ left: Config.headerSlot("left"), center: Config.headerSlot("center"), right: Config.headerSlot("right") })
  readonly property var barSlots: level === null ? slotsOf(topBar) : body.kinds[level.kind].bar(level)
  readonly property var barItems: barSlots.left.concat(barSlots.center, barSlots.right)
  // Never for the cursor's keys alone, so a level holds still as it shows (rule 4).
  readonly property bool barShown: barItems.length > 0 || barActions.length > 0 || legend.length > body.cursorLegend.length
  // What holding Ctrl or Super lists: the bar's keys, and its compositor shortcuts.
  readonly property var holds: ({
      Ctrl: barItems.filter(item => item.key).map(item => hint(item, MenuKeys.names(item.key).map(name => "Ctrl+" + name))),
      Super: barItems.filter(item => shortcutOf(item)).map(item => hint(item, shortcutOf(item)))
    })
  // Keys no row shows, listed on `?` where they act.
  readonly property var help: [].concat(
    viewModel?.help ?? [],
    holds.Ctrl.length ? [{ key: "Ctrl+", desc: Words.helpBarKeys }] : [],
    holds.Super.length ? [{ key: "Super+", desc: Words.helpCompositor }] : [],
    cursor.free.length ? [{ key: cursor.free, paired: true, desc: Words.helpMove }] : [],
    cursor.free.length && !content ? [{ key: "Return", desc: Words.helpRun }] : [],
    cursor.free.length && body.cursorRows.some(row => body.returnOf(row) !== "Return") ? [{ key: "Shift+Return", desc: Words.helpRunShifted }] : [],
    rows.some(row => row.actions?.length > 0 || row.app?.hasMenu) ? [{ key: "Alt+1", desc: Words.helpItemMenu }] : [],
    slashFilters ? [{ key: "/", desc: Words.helpFilter }] : [],
    input.input ? [{ key: "Tab", desc: Words.helpTab }, { key: "Ctrl+Shift+Return", desc: Words.helpSendLeave }] : [],
    input.plugin?.recalls ? [{ key: "Ctrl+r", desc: Words.helpRecall }] : [],
    [{ key: "Escape", desc: Words.helpEscape }]
  )
  readonly property bool slashFilters: body.slashFilters
  readonly property var hints: held === "Help" ? help : holds[held] ?? []
  readonly property var legend: body.legend
  readonly property string error: body.error

  function slotsOf(bar) {
    return { left: barOf(bar.left), center: barOf(bar.center), right: barOf(bar.right) };
  }

  // A name is a status or plugin to show, an entry with a list each of its items; `uid` is what the view follows an item by.
  function barOf(slot) {
    return Array.from(slot ?? []).reduce((items, part) => items.concat(typeof part === "string" ? [{ key: "", desc: part, status: part, uid: part }]
      : part.list ? barList(part).map(item => Object.assign({}, item, { uid: part.list + ":" + (item.id ?? "more") }))
      : [Object.assign(body.itemOf(part), { uid: part.key || part.desc })]), []);
  }

  function shortcutOf(item) {
    return item.entry ? item.entry.shortcut ?? "" : Plugins.get(item.status)?.shortcut ?? "";
  }

  function hint(item, key) {
    const glyph = Statuses.of(item.status).glyph;
    return Object.assign({}, item, { key, status: "", format: "", paired: typeof key !== "string", icon: item.icon || (item.image ? "" : glyph) });
  }

  // The app and the submenus opened since: blueman › Plugins.
  function appOf(menus) {
    return { key: "", desc: menus.map(menu => menu.title).join(" › "), image: menus[0]?.image ?? "", named: true };
  }

  // `limit` items on digits, then 0 for the rest, filtered on a level of its own.
  function barList(entry) {
    const all = Lists.items(entry.list);
    const shown = body.numbered(entry.list, entry.pins, all).slice(0, entry.limit ?? 9);
    const onBar = shown.map(item => item.id);
    const more = all.filter(item => !item.hidden && !onBar.includes(item.id)).length;
    return more > 0 ? shown.concat({ key: "0", desc: "+" + more, select: () => pickList(entry.list) }) : shown;
  }

  function keyChars(group) {
    return Math.max(1, ...group.map(item => MenuKeys.label(item.key, item.paired).length));
  }

  // Actions flow across, so a column is every nth one.
  function columnChars(index, columns) {
    return keyChars(bodyActions.filter((_, i) => i % columns === index % columns));
  }

  function show() {
    // Sources without change events are read as the menu opens.
    Compositor.refresh();
    Config.refresh();
    Plugins.refresh();
    Daemons.refresh();
    Panels.open(root);
  }

  function toggle() {
    if (open) hide();
    else show();
  }

  // By its key, in the body or the bar, as a compositor shortcut opens it.
  function toggleEntry(key) {
    const item = find(body.itemsOf(null).concat(barOf(topBar.left), barOf(topBar.center), barOf(topBar.right)), key);
    if (!item) return;
    // A bar list's item has no entry to toggle: it runs.
    if (item.entry && level?.entry === item.entry) {
      hide();
      return;
    }
    levels = [];
    if (!open) show();
    activate(item, key);
    base = levels.length;
  }

  // "body" or "input" (the level input).
  function focusOn(where) {
    internal.focus = where;
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
    body.stopFilter();
    internal.held = "";
    internal.focus = "body";
    cursor.point(undefined);
  }

  function back() {
    const left = level;
    levels = levels.slice(0, -1);
    body.stopFilter();
    internal.focus = left?.inputFocused ? "input" : "body";
    cursor.point(left?.cursor);
    body.clearViews();
  }

  function push(next) {
    levels = levels.concat([Object.assign({}, next, { inputFocused: inputFocused, cursor: cursor.current })]);
    body.stopFilter();
    internal.focus = "body";
    cursor.point(undefined);
    body.clearViews();
  }

  function find(candidates, name) {
    return candidates.find(item => MenuKeys.matches(item.key, name));
  }

  // A click on a pair runs nothing; an action keeps the menu open by default.
  function run(entry, name) {
    const action = body.actionOf(entry);
    if (action) {
      const second = MenuKeys.names(entry.key).indexOf(name);
      if (action.pair && second < 0) return;
      // Read before hide(), which leaves the level.
      const list = body.levelList;
      if (entry.keepOpen === false || action.closes) hide();
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
  function pickList(list) {
    const over = !open;
    if (over) Panels.remove(root);
    if (!open) show();
    push({ kind: "entry", entry: { list: list }, picking: true, width: Config.menu.width });
    if (over) base = levels.length;
    body.filterSlots = 9;
  }

  // Escape once the input is cleared: an input gives the keys back to its body first, as a card's reply does.
  function stepBack() {
    if (filtering && !level.picking) return body.stopFilter();
    if (inputFocused) return focusOn("body");
    if (viewModel && viewModel.stepBack()) return;
    if (levels.length <= base) Panels.back();
    else back();
  }

  // A digit picks a shown row and never types; with Alt, or Alt+Return, its own menu.
  function filterKey(name) {
    const digit = name.match(/^(Alt\+)?([1-9])$/);
    const row = digit ? filter.rows[Number(digit[2]) - 1] : filter.item;
    if (digit && digit[1] || name === "Alt+Return") openMenu(row);
    else if (digit || name === "Return" || name === "Shift+Return") choose(row);
    else if (name === "Up" || name === "Down") filter.move(name === "Down" ? 1 : -1);
    else if (name === "Page_Up" || name === "Page_Down") filter.move((name === "Page_Down" ? 1 : -1) * filter.size);
    else return false;
    return true;
  }

  function choose(item) {
    if (!item) return;
    filter.point(item.id);
    activate(item, item.key);
  }

  // Whether activating an item does anything: a name only shows, unless it is a plugin's, by name or an entry's status.
  function runs(item) {
    const entry = item.entry;
    return !!(item.select || Plugins.get(item.status ?? "") || entry && (entry.cmd || entry.action || entry.submenu || entry.list || entry.view));
  }

  function activate(item, name) {
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
      run(item.entry, name);
    }
  }

  // Alt with its digit, or a right click.
  function openMenu(item) {
    if (item?.actions?.length > 0) push({ kind: "actions", title: item.desc, icon: item.icon ?? "", actions: item.actions, width: width });
    else if (item?.app?.hasMenu) push({ kind: "menu", title: item.desc, image: item.image ?? "", handle: item.app.menu, width: width });
  }

  // The wheel, up as a pair's second key (more): a listed item adjusts itself, a pair steps, a row opening a level steps the pair its status adjusts.
  function act(item, up) {
    if (item.adjust) return item.adjust(up);
    const adjust = Statuses.of(item.status ?? "").adjust;
    const pair = item.entry?.submenu ? Array.from(item.entry.submenu).find(entry => adjust && entry.action === adjust) : item.paired ? item.entry : null;
    if (pair && body.available(pair)) run(pair, MenuKeys.names(pair.key)[up ? 1 : 0]);
  }

  // Escape and Tab are kept free by Validation.
  function handleKey(event) {
    // A bare modifier has no name, and Super belongs to the compositor.
    if (event.modifiers & Qt.MetaModifier) return false;
    // A held key repeats on the level it was pressed on, never into the one it opened; of the level's rows, only a pair steps on.
    if (event.isAutoRepeat && level !== internal.pressedOn) return true;
    if (!event.isAutoRepeat) internal.pressedOn = level;
    const name = MenuKeys.name(event);
    const own = event.isAutoRepeat ? find(items, name) : null;
    // Held, Return acts once on the cursor's row, a pair's too.
    if (own && !own.paired || event.isAutoRepeat && cursorItem && name.endsWith("Return")) return true;
    return handleName(name) || cursorKey(name);
  }

  // After the view and the level's rows, so a level binding an arrow keeps it; `press` never reaches it, so a key path never depends on the cursor.
  function cursorKey(name) {
    if (cursor.key(name)) return true;
    if (cursorItem && name === body.returnOf(cursorItem)) activate(cursorItem, cursorItem.key);
    else if (cursorItem && name === "Alt+Return") openMenu(cursorItem);
    else return false;
    return true;
  }

  function handleName(name) {
    if (!name) return false;
    const [, ctrl, alt, key] = name.match(/^(Ctrl\+)?(Alt\+)?(.*)$/);
    const own = find(items, name);
    const target = alt && /^[0-9]$/.test(key) ? find(ctrl ? barItems : rows, key) : null;
    const barred = ctrl && !alt ? find(barItems, key) : null;
    // Any key closes the help, which only lists keys.
    if (held === "Help") internal.held = "";
    else if (name === "?") internal.held = "Help";
    else if (name === "Escape") stepBack();
    else if (viewModel && viewModel.handleKey(name)) return true;
    else if (input.input && name === "Tab") internal.focus = "input";
    else if (own) activate(own, name);
    else if (name === "/" && slashFilters) body.startFilter();
    else if (target) openMenu(target);
    else if (barred) activate(barred, key);
    else return false;
    return true;
  }

  // A key path (`a 2`, `t Ctrl+x`) run from the top level as typing it would: what a binding reaches.
  function press(path) {
    const closed = !open;
    levels = [];
    if (!open) show();
    for (const [i, name] of path.trim().split(/\s+/).entries()) {
      // A key that closed the menu ends the path, so none past it opens a level on the closed menu.
      if (i > 0 && !inStack) return false;
      internal.ran = null;
      if (!(filtering ? filterKey(name) : handleName(name))) return false;
    }
    base = levels.length;
    // Opened for the path, the menu closes after the action it ends on, unless that opened a picker or another surface.
    if (closed && internal.ran && !internal.ran.keepOpen && open && !filtering) hide();
    return true;
  }

  // The key paths `press` takes, as Markdown.
  function keyMap() {
    const lines = [];
    const path = (prefix, key) => MenuKeys.names(key).map(name => "`" + (prefix + " " + name).trim() + "`").join(" ");
    // A bar's entries, on Ctrl in the level they sit on.
    const bar = (header, prefix, depth) => {
      for (const slot of ["left", "center", "right"]) {
        for (const part of Array.from(header?.[slot] ?? [])) {
          if (typeof part === "string" || !part.key) continue;
          const keys = MenuKeys.names(part.key).map(name => "`" + (prefix + " Ctrl+" + name).trim() + "`").join(" ");
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
        bar(entry.header, at, depth + 1);
      }
    };
    walk(entries, "", 0);
    bar(topBar, "", 0);
    return lines.join("\n");
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
    property var pressedOn: null
    // The entry or item whose action the last key ran.
    property var ran: null
  }
}
