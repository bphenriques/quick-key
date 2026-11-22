import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.builtins
import qs.widgets.menu.calendar

// The menu's state and keys; a level is its bar over its body, each a list of items { key, desc, ... }, static or filled at runtime.
Scope {
  id: root

  // On top of Panels, shown; in its stack, shown or under a plugin's panel, its levels and its visit held until it leaves the stack.
  readonly property bool open: Panels.top === root
  readonly property bool inStack: Panels.stack.includes(root)
  onInStackChanged: if (!inStack) reset()
  // Levels opened below the top one, the last is shown: an entry's (kind "entry"), an app's own menu (kind "menu") or a listed item's (kind "actions"). Each keeps `inputFocused` as it was below it, for Escape to give back.
  property var stack: []
  // How deep the menu opened (a level opened on its own by a shortcut or a key path), where Escape closes it.
  property int base: 0
  // What lists keys in place of the body: "Ctrl" or "Super" held a second (not at once, so a chord does not flash them), or "Help" after `?`.
  property string held: ""
  // Whether the level's input has the keys, else its body.
  property bool inputFocused: false
  // Whether Tab moved the keys on to the answer over the input, where Return opens the plugin's panel.
  property bool answerFocused: false
  readonly property CalendarModel calendar: CalendarModel {}

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  readonly property var level: stack[stack.length - 1] ?? null
  readonly property bool inCalendar: level?.entry?.view === "calendar"
  // The level's input and what it starts: its plugin, turn, drafts and visit.
  readonly property InputModel island: InputModel {
    menu: root
  }
  // Whether `/` filters the level's list in place (pick); a level opened to pick from (Picker, a bar's +N) always does.
  property bool filterOn: false
  readonly property bool filtering: (filterOn || !!level?.picking) && !!level?.entry?.list
  // Its rows held while filtering, so the body keeps its height: the level's own, nine on a level opened to pick.
  property int filterSlots: 9
  readonly property ListFilter filter: ListFilter {
    size: root.filterSlots
    items: root.filtering ? root.ordered(root.level.entry.list, root.level.entry.pins, root.levelList).filter(item => item.id !== undefined) : []
  }
  // What the level lists, read once for every entry that acts on it.
  readonly property var levelList: Lists.items(level?.entry?.list)
  readonly property var items: itemsOf(level)
  readonly property var actions: items.filter(item => !item.listed)
  // A level with a list or a view is its content, its actions on its bar (rule 4); any other is a menu, its actions its rows.
  readonly property bool content: level?.kind === "entry" && !!(level.entry.list || level.entry.view)
  readonly property var bodyActions: content ? [] : actions
  readonly property var barActions: content && !filtering ? actions : []
  readonly property var rows: filtering ? filter.rows : items.filter(item => item.listed)
  readonly property int width: level?.width ?? Config.menu.width
  // Its actions' columns: its entry's own, else menu.columns.
  readonly property int columns: level?.entry?.columns ?? Config.menu.columns
  // Why a level's list is empty, in its place; "" while it lists something.
  readonly property string emptyText: level?.entry?.list && rows.length === 0 ? (filtering && filter.emptyText) || Lists.empty(level.entry.list) : ""
  readonly property var topBar: ({ left: Config.headerSlot("left"), center: Config.headerSlot("center"), right: Config.headerSlot("right") })
  // The level's bar by slot: the top level's is menu.header, else the starter's, an entry's its own `header`, an app's menu the app and the way into it (blueman › Plugins).
  readonly property var bar: level === null ? topBar
    : level.kind === "entry" ? level.entry.header ?? {} : {}
  readonly property var barSlots: level?.kind === "menu" ? { left: [appOf(stack.filter(level => level.kind === "menu"))], center: [], right: [] }
    : level?.kind === "actions" ? { left: [{ key: "", desc: level.title, icon: level.icon, named: true }], center: [], right: [] }
    : { left: barOf(bar.left), center: barOf(bar.center), right: barOf(bar.right) }
  readonly property var barItems: barSlots.left.concat(barSlots.center, barSlots.right)
  // A level with nothing for its bar is its body alone.
  readonly property bool barShown: barItems.length > 0 || barActions.length > 0 || legend.length > 0
  // The keys no row shows, listed on `?`: holds, an item's own menu, and back.
  readonly property var help: [
    { key: "Ctrl+", desc: Words.helpBarKeys },
    { key: "Super+", desc: Words.helpCompositor },
    { key: "Alt+1", desc: Words.helpItemMenu }
  ].concat(slashFilters ? [{ key: "/", desc: Words.helpFilter }] : [], island.input ? [{ key: "Tab", desc: Words.helpTab }, { key: "Ctrl+Shift+Return", desc: Words.helpBackground }] : [], island.plugin?.recalls ? [{ key: "Ctrl+r", desc: Words.helpRecall }] : [], [
    { key: "Escape", desc: Words.helpEscape }
  ])
  // `/` filters the level's list, unless the level binds it itself.
  readonly property bool slashFilters: !!level?.entry?.list && !find(items, "/")
  readonly property int unhidden: levelList.filter(item => !item.hidden).length
  // The keys listed in place of the body: the help, the bar's while Ctrl is held, the compositor's while Super is.
  readonly property var hints: held === "Help" ? help : held === "Ctrl" ? barItems.filter(item => item.key).map(item => hint(item, MenuKeys.names(item.key).map(name => "Ctrl+" + name)))
    : held === "Super" ? barItems.filter(item => shortcutOf(item)).map(item => hint(item, shortcutOf(item))) : []
  // Keys a level takes beyond its rows, after its actions on its bar (KeyLegend): { key, what }, only what the state changes (fixed keys are `?`'s), and `/` while the list holds more than its rows.
  readonly property var levelLegend: (inCalendar ? calendar.legend : Lists.builtin[level?.entry?.list]?.legend ?? [])
    .concat(slashFilters && unhidden > 9 ? [{ key: "/", what: Words.shownOf(unhidden), clickable: true }] : [])
  readonly property var legend: filtering ? filter.legend : levelLegend
  // Why a level's source failed, at the end of its body: the calendar's sync, or the plugin it lists.
  readonly property string error: inCalendar ? (Calendar.syncing ? "" : Calendar.error) : Plugins.get(level?.entry?.list ?? "")?.error ?? ""

  // An entry as a row or a bar item shows it.
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

  function itemsOf(level) {
    if (level === null) return entries.map(itemOf);
    if (level.kind === "menu") {
      const children = Array.from(menuOpener.children.values).filter(child => !child.isSeparator && child.enabled);
      const labels = children.map(child => child.text.replace(/_/g, ""));
      const keys = MenuKeys.assign(labels);
      return children.map((child, i) => ({
        key: keys[i],
        desc: labels[i],
        glyphs: child.checkState === Qt.Checked ? [Glyphs.check] : child.hasChildren ? [Glyphs.submenu] : [],
        select: child.hasChildren ? () => push({ kind: "menu", title: labels[i], handle: child, width: level.width }) : () => {
          // Before hide(), which releases the menu this entry belongs to.
          child.triggered();
          hide();
        }
      }));
    }
    // A listed item's own menu: its actions by their keys, each stepping back to the list once run.
    if (level.kind === "actions") {
      return Array.from(level.actions).map(action => ({
        key: action.key,
        desc: action.desc,
        icon: action.icon,
        closes: action.closes,
        select: () => {
          if (!action.closes) back();
          action.select();
        }
      }));
    }

    // An entry's own rows by letter, in their level (a value beside its label, with its meter), then what its list holds by digit.
    const own = Array.from(level.entry.submenu ?? []).map(entry => Object.assign(itemOf(entry), { listed: /^[0-9]$/.test(entry.key), inLevel: true }));
    return own.concat(numbered(level.entry.list, level.entry.pins));
  }

  // A bar slot's items: a name is a status or plugin to show, an entry with a list each of its items, any other entry itself.
  function barOf(slot) {
    return Array.from(slot ?? []).reduce((items, part) => items.concat(typeof part === "string" ? [{ key: "", desc: part, status: part }]
      : part.list ? barList(part) : [itemOf(part)]), []);
  }

  // A bar item's compositor key: its entry's `shortcut`, or a plugin's.
  function shortcutOf(item) {
    return item.entry ? item.entry.shortcut ?? "" : Plugins.get(item.status)?.shortcut ?? "";
  }

  // A bar item as a line of the legend: its key, its icon (its status's glyph when it shows a status) and its name.
  function hint(item, key) {
    const glyph = Statuses.builtin[item.status]?.glyph() ?? Plugins.get(item.status)?.glyph ?? "";
    return Object.assign({}, item, { key, status: "", format: "", paired: typeof key !== "string", icon: item.icon || (item.image ? "" : glyph) });
  }

  // An app's menu as its bar shows it: the app's icon, and its name with the submenus opened since.
  function appOf(menus) {
    return { key: "", desc: menus.map(menu => menu.title).join(" › "), image: menus[0]?.image ?? "", named: true };
  }

  // A list in a bar: its `limit` (at most nine) on digits, then 0 for the whole list, filtered on a level of its own, when there are more.
  function barList(entry) {
    const all = Lists.items(entry.list);
    const shown = numbered(entry.list, entry.pins, all).slice(0, entry.limit ?? 9);
    const onBar = shown.map(item => item.id);
    const more = all.filter(item => !item.hidden && !onBar.includes(item.id)).length;
    return more > 0 ? shown.concat({ key: "0", desc: "+" + more, select: () => pickList(entry.list, null) }) : shown;
  }

  // Pins first, each keeping its digit, dimmed while what it matches is absent; the rest follow in the list's order.
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

  // The rows at rest: the first nine on fixed digits, a hidden item only when filtering.
  function numbered(list, pins, items = Lists.items(list)) {
    return ordered(list, pins, Array.from(items).filter(item => !item.hidden)).slice(0, 9).map((item, i) => Object.assign({}, item, { key: String(i + 1), listed: true }));
  }

  // The widest key of a group of items, in characters.
  function keyChars(group) {
    return Math.max(1, ...group.map(item => MenuKeys.label(item.key, item.paired).length));
  }

  // Actions flow across, so a column is every nth one.
  function columnChars(index, columns) {
    return keyChars(bodyActions.filter((_, i) => i % columns === index % columns));
  }

  // Whether an entry can run now: a command always, an action when it has something to act on.
  function available(entry) {
    return entry.action ? actionOf(entry)?.available(levelList) ?? false : true;
  }

  // A built-in action by name, else the one of the plugin its level lists.
  function actionOf(entry) {
    return Actions.builtin[entry.action] ?? Plugins.get(level?.entry?.list ?? "")?.actions?.[entry.action];
  }

  // A pair runs one command or action per key, shown as one row (Down and Up).
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
    Plugins.refresh();
    Daemons.refresh();
    Panels.open(root);
  }

  function toggle() {
    if (open) hide();
    else show();
  }

  // A top-level entry by its key, in the body or the bar, as a compositor shortcut opens it.
  function toggleEntry(key) {
    const item = find(itemsOf(null).concat(barOf(topBar.left), barOf(topBar.center), barOf(topBar.right)), key);
    if (!item) return;
    if (level?.entry === item.entry) {
      hide();
      return;
    }
    stack = [];
    if (!open) show();
    activate(item, key);
    base = stack.length;
  }

  // Closes it and whatever it was over, fresh for its next opening.
  function hide() {
    Panels.close();
    reset();
  }

  // As it leaves the stack: the top level again, nothing filtered, held or focused.
  function reset() {
    stack = [];
    base = 0;
    stopFilter();
    held = "";
    inputFocused = false;
    answerFocused = false;
  }

  // A level starts with no event in focus, coming back to it too, and its input as it was left.
  function back() {
    const left = level;
    stack = stack.slice(0, -1);
    stopFilter();
    inputFocused = !!left?.inputFocused;
    answerFocused = false;
    calendar.focused = "";
  }

  function push(next) {
    stack = stack.concat([Object.assign({}, next, { inputFocused: inputFocused })]);
    stopFilter();
    inputFocused = false;
    answerFocused = false;
    calendar.focused = "";
  }

  function find(candidates, name) {
    return candidates.find(item => MenuKeys.matches(item.key, name));
  }

  // A pair runs the command or action of the key pressed, a click on it nothing; an action keeps the menu open by default.
  function run(entry, name) {
    const action = actionOf(entry);
    if (action) {
      const second = MenuKeys.names(entry.key).indexOf(name);
      if (action.pair && second < 0) return;
      // Read before hide(), which leaves the level.
      const list = levelList;
      if (entry.keepOpen === false || action.closes) hide();
      action.run(second === 1, list, root);
      return;
    }
    const cmd = MenuKeys.isPair(entry) ? Array.from(entry.cmd)[MenuKeys.names(entry.key).indexOf(name)] : entry.cmd;
    // No command: an entry showing a plugin activates it, as a click on it in a bar does.
    if (!cmd) return Plugins.get(entry.status ?? "")?.activate();
    if (!entry.keepOpen) hide();
    Commands.run(cmd);
  }

  // The level's list filtered in place, the filter in its island with the keys; as many rows held as it shows.
  function startFilter() {
    if (!level?.entry?.list) return;
    filterSlots = Math.max(1, rows.length);
    filterOn = true;
  }

  function stopFilter() {
    filterOn = false;
    filter.reset();
  }

  // A list on a level of its own, filtering from the start: a bar's +N, or what a plugin's panel asks for (Picker), opened over that panel, its only level, so Escape shows the panel again.
  function pickList(list) {
    const over = !open;
    if (over) Panels.remove(root);
    if (!open) show();
    push({ kind: "entry", entry: { list: list }, picking: true, width: Config.menu.width });
    if (over) base = stack.length;
    filterSlots = 9;
  }

  // Escape once its text is cleared: what is open on top (the filter, a focused event), then back where the level came from, closing where the menu opened.
  function stepBack() {
    if (filtering && !level.picking) return stopFilter();
    if (inCalendar && calendar.focused) {
      calendar.focused = "";
      return;
    }
    if (stack.length <= base) Panels.back();
    else back();
  }

  // The keys the filter leaves, by name: a digit picks a row shown and never types, Alt with it or Return its own menu.
  function filterKey(name) {
    const digit = name.match(/^(Alt\+)?([1-9])$/);
    const row = digit ? filter.rows[Number(digit[2]) - 1] : filter.item;
    if (digit && digit[1] || name === "Alt+Return") openMenu(row);
    else if (digit || name === "Return") choose(row);
    else if (name === "Up" || name === "Down") filter.move(name === "Down" ? 1 : -1);
    else return false;
    return true;
  }

  // Runs as its digit would at rest, the cursor staying on it.
  function choose(item) {
    if (!item) return;
    filter.current = item.id;
    activate(item, item.key);
  }

  // A listed item does what it says; an entry with a level below opens it, any other runs; a plugin's name in a bar activates it.
  function activate(item, name) {
    if (item.enabled === false) return;
    if (item.select) {
      if (item.closes) hide();
      item.select();
    } else if (!item.entry) {
      Plugins.get(item.status)?.activate();
    } else if (item.entry.submenu || item.entry.list || item.entry.view) {
      calendar.reset();
      push({ kind: "entry", entry: item.entry, width: item.entry.width });
    } else {
      run(item.entry, name);
    }
  }

  // An item's own menu, its actions or a tray app's: Alt with its digit, or a right click.
  function openMenu(item) {
    if (item?.actions?.length > 0) push({ kind: "actions", title: item.desc, icon: item.icon ?? "", actions: item.actions, width: width });
    else if (item?.app?.hasMenu) push({ kind: "menu", title: item.desc, image: item.image ?? "", handle: item.app.menu, width: width });
  }

  // The mouse wheel on a row: a listed item adjusts itself (a device's volume); a pair runs itself; an entry runs the action of its own on that key, e.g. volume.
  function act(item, name) {
    if (item.adjust) return item.adjust(name === "Up");
    const action = item.entry?.submenu ? find(Array.from(item.entry.submenu), name) : MenuKeys.matches(item.entry?.key ?? [], name) ? item.entry : null;
    if (action && available(action)) run(action, name);
  }

  // The body's keys first, then Alt for an item's own menu and Ctrl for the bar (with Alt, a bar item's own menu); Escape and Tab are kept free by the check.
  function handleKey(event) {
    // A modifier on its own has no name, and Super belongs to the compositor: a chord with it runs nothing here.
    if (event.modifiers & Qt.MetaModifier) return false;
    return handleName(MenuKeys.name(event));
  }

  function handleName(name) {
    if (!name) return false;
    const [, ctrl, alt, key] = name.match(/^(Ctrl\+)?(Alt\+)?(.*)$/);
    const own = find(items, name);
    const target = alt && /^[0-9]$/.test(key) ? find(ctrl ? barItems : rows, key) : null;
    const barred = ctrl && !alt ? find(barItems, key) : null;
    // Any key closes the help, which only lists keys.
    if (held === "Help") held = "";
    else if (name === "?") held = "Help";
    else if (answerFocused && island.answerKey(name)) return true;
    else if (name === "Escape") stepBack();
    else if (inCalendar && calendar.handleKey(name)) return true;
    else if (island.input && name === "Tab") inputFocused = true;
    else if (own) activate(own, name);
    else if (name === "/" && slashFilters) startFilter();
    else if (target) openMenu(target);
    else if (barred) activate(barred, key);
    else return false;
    return true;
  }

  // A key path (`a 2`, `t Ctrl+x`), each key named as entries declare it, run from the top level as typing it would: what a compositor binding or a terminal reaches.
  function press(path) {
    stack = [];
    if (!open) show();
    for (const name of path.trim().split(/\s+/)) {
      if (!(filtering ? filterKey(name) : handleName(name))) return false;
    }
    base = stack.length;
    return true;
  }

  // Every entry's key path and name, as Markdown, from menu.entries and the top level's bar: the paths `press` takes.
  function keyMap() {
    const lines = [];
    const path = (prefix, key) => MenuKeys.names(key).map(name => "`" + (prefix + " " + name).trim() + "`").join(" ");
    const walk = (entries, prefix, depth) => {
      for (const entry of Array.from(entries ?? [])) {
        const at = (prefix + " " + MenuKeys.names(entry.key ?? "")[0]).trim();
        lines.push("  ".repeat(depth) + "- " + path(prefix, entry.key ?? "") + " " + (entry.desc ?? entry.status ?? ""));
        for (const [i, pin] of Array.from(entry.pins ?? []).entries()) lines.push("  ".repeat(depth + 1) + "- `" + at + " " + (i + 1) + "` " + pin.label);
        if (entry.list) lines.push("  ".repeat(depth + 1) + "- `" + at + " 1-9` " + entry.list);
        walk(entry.submenu, at, depth + 1);
      }
    };
    walk(entries, "", 0);
    for (const slot of ["left", "center", "right"]) {
      for (const part of Array.from(topBar[slot] ?? [])) {
        if (typeof part !== "string" && part.key) lines.push("- " + MenuKeys.names(part.key).map(name => "`Ctrl+" + name + "`").join(" ") + " " + (part.desc ?? part.status ?? ""));
      }
    }
    return lines.join("\n");
  }

  // What a plugin's panel asks for (Ask's C-r): a list filtered on a level of its own.
  Connections {
    target: Picker

    function onRequested(list) {
      root.pickList(list);
    }
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.level?.kind === "menu" ? root.level.handle : null
  }
}
