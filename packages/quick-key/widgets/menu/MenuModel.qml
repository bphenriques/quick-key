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
  readonly property bool inStack: Panels.stack.includes(root)
  onInStackChanged: if (!inStack) reset()
  // Levels past the top one: an entry ("entry"), an app menu ("menu") or an item menu ("actions"), each keeping inputFocused for Escape to restore.
  property var stack: []
  // How deep a shortcut or key path opened it: Escape closes there.
  property int base: 0
  // "Ctrl" or "Super" held a second (so a chord does not flash them), or "Help" after `?`.
  readonly property string held: internal.held
  readonly property bool inputFocused: internal.focus === "input"

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  readonly property var level: stack[stack.length - 1] ?? null
  // A model per view in Views, made from the file it names.
  readonly property var viewModels: Object.keys(Views.builtin)
    .reduce((models, name) => Object.assign(models, { [name]: Qt.createComponent(Views.builtin[name].model).createObject(root) }), {})
  readonly property var viewModel: viewModels[level?.entry?.view] ?? null
  readonly property var view: viewModel ? Views.builtin[level.entry.view] : null
  readonly property InputModel island: InputModel {
    menu: root
  }
  // A level opened to pick (Picker, a bar +N) always filters.
  property bool filterOn: false
  readonly property bool filtering: (filterOn || !!level?.picking) && !!level?.entry?.list
  // Rows held while filtering, so the body keeps its height.
  property int filterSlots: 9
  readonly property ListFilter filter: ListFilter {
    size: root.filterSlots
    items: root.filtering ? root.ordered(root.level.entry.list, root.level.entry.pins, root.levelList).filter(item => item.id !== undefined) : []
  }
  // Read once for every entry that acts on it.
  readonly property var levelList: Lists.items(level?.entry?.list)
  readonly property var items: itemsOf(level)
  readonly property var actions: items.filter(item => !item.listed)
  // A level with a list or a view is its content, its actions on its bar (rule 4); any other is a menu, its actions its rows.
  readonly property bool content: level !== null && kinds[level.kind].content(level)
  readonly property var bodyActions: content ? [] : actions.map(marked)
  readonly property var barActions: content && !filtering ? actions : []
  readonly property var rows: filtering ? filter.rows : items.filter(item => item.listed).map(marked)
  // At rest the arrows move a cursor over a list level's rows, or a menu's grid, by the pairs its own rows leave free (rule 7); `press` never reaches it.
  readonly property var cursorRows: filtering || viewModel ? [] : content ? items.filter(item => item.listed && item.id !== undefined) : actions
  readonly property Cursor cursor: Cursor {
    ids: root.cursorRows.map(root.idOf)
    columns: root.content ? 1 : root.columns
    free: [["Up", "Down"]].concat(root.content ? [] : [["Left", "Right"]]).filter(pair => root.cursorRows.length && !pair.some(key => root.find(root.items, key))).reduce((all, pair) => all.concat(pair), [])
    from: root.content ? root.cursorRows.find(row => row.active)?.id : undefined
  }
  // What Return runs, filtering or at rest.
  readonly property var cursorItem: filtering ? filter.rows.find(row => row.current) ?? null : cursorRows.find(row => idOf(row) === cursor.current) ?? null
  readonly property int width: level?.width ?? Config.menu.width
  // No more columns than its width holds at about twelve characters each.
  readonly property int columns: Math.max(1, Math.min(level?.entry?.columns ?? Config.menu.columns, Math.floor(width / (12 * Metrics.cell))))
  readonly property string emptyText: level?.entry?.list && rows.length === 0 ? (filtering && filter.emptyText) || Lists.empty(level.entry.list) : ""
  readonly property var topBar: ({ left: Config.headerSlot("left"), center: Config.headerSlot("center"), right: Config.headerSlot("right") })
  readonly property var barSlots: level === null ? slotsOf(topBar) : kinds[level.kind].bar(level)
  readonly property var barItems: barSlots.left.concat(barSlots.center, barSlots.right)
  readonly property bool barShown: barItems.length > 0 || barActions.length > 0 || legend.length > 0
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
    rows.some(row => row.actions?.length > 0 || row.app?.hasMenu) ? [{ key: "Alt+1", desc: Words.helpItemMenu }] : [],
    slashFilters ? [{ key: "/", desc: Words.helpFilter }] : [],
    island.input ? [{ key: "Tab", desc: Words.helpTab }, { key: "Ctrl+Shift+Return", desc: Words.helpSendLeave }] : [],
    island.plugin?.recalls ? [{ key: "Ctrl+r", desc: Words.helpRecall }] : [],
    [{ key: "Escape", desc: Words.helpEscape }]
  )
  readonly property bool slashFilters: !!level?.entry?.list && !find(items, "/")
  readonly property int unhidden: levelList.filter(item => !item.hidden).length
  readonly property var hints: held === "Help" ? help : holds[held] ?? []
  // Only keys the state changes; fixed ones are listed on `?`, and show here too as its entry's `legend` names them.
  readonly property var levelLegend: (viewModel ? viewModel.legend : Lists.builtin[level?.entry?.list]?.legend ?? [])
    .concat(slashFilters && unhidden > 9 ? [{ key: "/", what: Words.shownOf(unhidden), clickable: true }] : [])
    // At the top, the key listing the rest, which every surface with such a list shows so.
    .concat(level === null && Config.menu.keysHint ? [{ key: "?", what: Words.help, clickable: true }] : [])
    .concat(MenuKeys.pick(help, level?.entry?.legend))
  readonly property var cursorLegend: (cursorItem ? [{ key: "Return", what: cursorItem.verb || Words.pick, clickable: true }] : [])
    .concat(cursorItem?.actions?.length > 0 || cursorItem?.app?.hasMenu ? [{ key: "Alt+Return", what: Words.menu, clickable: true }] : [])
  readonly property var legend: filtering ? filter.legend.concat(cursorLegend, filter.query ? [{ key: "Escape", what: Words.clear, clickable: true }] : []) : levelLegend.concat(cursorLegend)
  readonly property string error: viewModel ? viewModel.error : Plugins.get(level?.entry?.list ?? "")?.error ?? (level ? "" : Config.broken)

  function itemOf(entry) {
    const action = actionOf(entry);
    return {
      key: entry.key ?? "",
      desc: entry.desc,
      status: entry.status ?? "",
      format: entry.format ?? "",
      icon: entry.icon ?? (action ? action.icon() : ""),
      detail: action?.detail ? action.detail(levelList) : "",
      enabled: available(entry),
      paired: isPair(entry),
      active: isOn(entry.activeWhen ?? action?.state),
      entry: entry
    };
  }

  // Each kind of level: its items, whether it is content (actions on its bar), and its bar; a new kind is one more here.
  readonly property var kinds: ({
      entry: {
        content: level => !!(level.entry.list || level.entry.view),
        bar: level => root.slotsOf(level.entry.header ?? {}),
        // Own rows by letter (inLevel: a value beside the label, with its meter), then the list by digit.
        items: level => Array.from(level.entry.submenu ?? [])
          .map(entry => Object.assign(root.itemOf(entry), { listed: /^[0-9]$/.test(entry.key), inLevel: true }))
          .concat(root.numbered(level.entry.list, level.entry.pins))
      },
      menu: {
        content: () => false,
        bar: () => ({ left: [root.appOf(root.stack.filter(level => level.kind === "menu"))], center: [], right: [] }),
        items: level => {
          const children = Array.from(menuOpener.children.values).filter(child => !child.isSeparator && child.enabled);
          const labels = children.map(child => child.text.replace(/_/g, ""));
          const keys = MenuKeys.assign(labels);
          return children.map((child, i) => ({
            key: keys[i],
            desc: labels[i],
            glyphs: child.checkState === Qt.Checked ? [Glyphs.check] : child.hasChildren ? [Glyphs.submenu] : [],
            select: child.hasChildren ? () => root.push({ kind: "menu", title: labels[i], handle: child, width: level.width }) : () => {
              // Before hide(), which releases the menu this entry belongs to.
              child.triggered();
              root.hide();
            }
          }));
        }
      },
      actions: {
        content: () => false,
        bar: level => ({ left: [{ key: "", desc: level.title, icon: level.icon, named: true }], center: [], right: [] }),
        items: level => Array.from(level.actions).map(action => ({
            key: action.key,
            desc: action.desc,
            icon: action.icon,
            closes: action.closes,
            select: () => {
              if (!action.closes) root.back();
              action.select();
            }
          }))
      }
    })

  function itemsOf(level) {
    return level === null ? entries.map(itemOf) : kinds[level.kind].items(level);
  }

  function slotsOf(bar) {
    return { left: barOf(bar.left), center: barOf(bar.center), right: barOf(bar.right) };
  }

  function clearViews() {
    for (const model of Object.values(viewModels)) model.clearFocus();
  }

  // A name is a status or plugin to show, an entry with a list each of its items; `uid` is what the view follows an item by.
  function barOf(slot) {
    return Array.from(slot ?? []).reduce((items, part) => items.concat(typeof part === "string" ? [{ key: "", desc: part, status: part, uid: part }]
      : part.list ? barList(part).map(item => Object.assign({}, item, { uid: part.list + ":" + (item.id ?? "more") }))
      : [Object.assign(itemOf(part), { uid: part.key || part.desc })]), []);
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
    const shown = numbered(entry.list, entry.pins, all).slice(0, entry.limit ?? 9);
    const onBar = shown.map(item => item.id);
    const more = all.filter(item => !item.hidden && !onBar.includes(item.id)).length;
    return more > 0 ? shown.concat({ key: "0", desc: "+" + more, select: () => pickList(entry.list) }) : shown;
  }

  // Pins keep their digit, dimmed while what they match is absent.
  function ordered(list, pins, items) {
    const rest = Array.from(items);
    const pinned = Array.from(pins ?? []).map(pin => {
      const index = rest.findIndex(item => MenuKeys.glob(pin.match, item.id));
      if (index < 0) return { desc: pin.label, icon: pin.icon ?? Lists.builtin[list]?.icon ?? Glyphs.tray, enabled: false };
      const item = rest.splice(index, 1)[0];
      return Object.assign({}, item, { desc: pin.label, icon: pin.icon ?? item.icon });
    });
    return pinned.concat(rest);
  }

  // A hidden item shows only when filtering.
  function numbered(list, pins, items = Lists.items(list)) {
    return ordered(list, pins, Array.from(items).filter(item => !item.hidden)).slice(0, 9).map((item, i) => Object.assign({}, item, { key: String(i + 1), listed: true }));
  }

  // A listed item by its id, a row by its first key, else its label.
  function idOf(item) {
    return item.listed ? item.id : MenuKeys.names(item.key ?? "")[0] || item.desc;
  }

  function marked(item) {
    return item === cursorItem ? Object.assign({ current: true }, item) : item;
  }

  function keyChars(group) {
    return Math.max(1, ...group.map(item => MenuKeys.label(item.key, item.paired).length));
  }

  // Actions flow across, so a column is every nth one.
  function columnChars(index, columns) {
    return keyChars(bodyActions.filter((_, i) => i % columns === index % columns));
  }

  // A command can always run; an action when it has something to act on.
  function available(entry) {
    return entry.action ? actionOf(entry)?.available(levelList) ?? false : true;
  }

  function actionOf(entry) {
    return Actions.builtin[entry.action] ?? Plugins.get(level?.entry?.list ?? "")?.actions?.[entry.action];
  }

  // One row running one command or action per key (Down and Up).
  function isPair(entry) {
    return MenuKeys.isPair(entry) || !!actionOf(entry)?.pair;
  }

  function isOn(state) {
    const read = States.builtin[state];
    return read ? read() : Plugins.get(state)?.active ?? false;
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
    const item = find(itemsOf(null).concat(barOf(topBar.left), barOf(topBar.center), barOf(topBar.right)), key);
    if (!item) return;
    // A bar list's item has no entry to toggle: it runs.
    if (item.entry && level?.entry === item.entry) {
      hide();
      return;
    }
    stack = [];
    if (!open) show();
    activate(item, key);
    base = stack.length;
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
    stack = [];
    base = 0;
    stopFilter();
    internal.held = "";
    internal.focus = "body";
    cursor.point(undefined);
  }

  function back() {
    const left = level;
    stack = stack.slice(0, -1);
    stopFilter();
    internal.focus = left?.inputFocused ? "input" : "body";
    cursor.point(undefined);
    clearViews();
  }

  function push(next) {
    stack = stack.concat([Object.assign({}, next, { inputFocused: inputFocused })]);
    stopFilter();
    internal.focus = "body";
    cursor.point(undefined);
    clearViews();
  }

  function find(candidates, name) {
    return candidates.find(item => MenuKeys.matches(item.key, name));
  }

  // A click on a pair runs nothing; an action keeps the menu open by default.
  function run(entry, name) {
    const action = actionOf(entry);
    if (action) {
      const second = MenuKeys.names(entry.key).indexOf(name);
      if (action.pair && second < 0) return;
      // Read before hide(), which leaves the level.
      const list = levelList;
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

  function startFilter() {
    if (!level?.entry?.list) return;
    filterSlots = Math.max(1, rows.length);
    filter.point(cursor.current ?? "");
    filterOn = true;
  }

  function stopFilter() {
    filterOn = false;
    filter.reset();
  }

  // Over a plugin panel it is the only level, so Escape shows the panel again.
  function pickList(list) {
    const over = !open;
    if (over) Panels.remove(root);
    if (!open) show();
    push({ kind: "entry", entry: { list: list }, picking: true, width: Config.menu.width });
    if (over) base = stack.length;
    filterSlots = 9;
  }

  // Escape once the input is cleared: an input gives the keys back to its body first, as a card's reply does.
  function stepBack() {
    if (filtering && !level.picking) return stopFilter();
    if (inputFocused) return focusOn("body");
    if (viewModel && viewModel.stepBack()) return;
    if (stack.length <= base) Panels.back();
    else back();
  }

  // A digit picks a shown row and never types; with Alt, or Alt+Return, its own menu.
  function filterKey(name) {
    const digit = name.match(/^(Alt\+)?([1-9])$/);
    const row = digit ? filter.rows[Number(digit[2]) - 1] : filter.item;
    if (digit && digit[1] || name === "Alt+Return") openMenu(row);
    else if (digit || name === "Return") choose(row);
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
      const next = viewModels[item.entry.view];
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
    if (pair && available(pair)) run(pair, MenuKeys.names(pair.key)[up ? 1 : 0]);
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
    if (own && !own.paired || event.isAutoRepeat && cursorItem && name === "Return") return true;
    return handleName(name) || cursorKey(name);
  }

  // After the view and the level's rows, so a level binding an arrow keeps it; `press` never reaches it, so a key path never depends on the cursor.
  function cursorKey(name) {
    if (cursor.key(name)) return true;
    if (cursorItem && name === "Return") activate(cursorItem, cursorItem.key);
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
    else if (island.input && name === "Tab") internal.focus = "input";
    else if (own) activate(own, name);
    else if (name === "/" && slashFilters) startFilter();
    else if (target) openMenu(target);
    else if (barred) activate(barred, key);
    else return false;
    return true;
  }

  // A key path (`a 2`, `t Ctrl+x`) run from the top level as typing it would: what a binding reaches.
  function press(path) {
    const closed = !open;
    stack = [];
    if (!open) show();
    for (const [i, name] of path.trim().split(/\s+/).entries()) {
      // A key that closed the menu ends the path, so none past it opens a level on the closed menu.
      if (i > 0 && !inStack) return false;
      internal.ran = null;
      if (!(filtering ? filterKey(name) : handleName(name))) return false;
    }
    base = stack.length;
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

  QsMenuOpener {
    id: menuOpener
    menu: root.level?.handle ?? null
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
