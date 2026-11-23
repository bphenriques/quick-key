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
  // Tab moved the keys to the answer, where Return opens the plugin panel.
  readonly property bool answerFocused: internal.focus === "answer"

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
  readonly property var bodyActions: content ? [] : actions
  readonly property var barActions: content && !filtering ? actions : []
  readonly property var rows: filtering ? filter.rows : items.filter(item => item.listed)
  readonly property int width: level?.width ?? Config.menu.width
  // No more columns than its width holds at about twelve characters each.
  readonly property int columns: Math.max(1, Math.min(level?.entry?.columns ?? Config.menu.columns, Math.floor(width / (12 * Metrics.cell))))
  readonly property string emptyText: level?.entry?.list && rows.length === 0 ? (filtering && filter.emptyText) || Lists.empty(level.entry.list) : ""
  readonly property var topBar: ({ left: Config.headerSlot("left"), center: Config.headerSlot("center"), right: Config.headerSlot("right") })
  readonly property var barSlots: level === null ? slotsOf(topBar) : kinds[level.kind].bar(level)
  readonly property var barItems: barSlots.left.concat(barSlots.center, barSlots.right)
  readonly property bool barShown: barItems.length > 0 || barActions.length > 0 || legend.length > 0
  // Keys no row shows, listed on `?`.
  readonly property var help: [
    { key: "Ctrl+", desc: Words.helpBarKeys },
    { key: "Super+", desc: Words.helpCompositor },
    { key: "Alt+1", desc: Words.helpItemMenu }
  ].concat(
    slashFilters ? [{ key: "/", desc: Words.helpFilter }] : [],
    island.input ? [{ key: "Tab", desc: Words.helpTab }, { key: "Ctrl+Shift+Return", desc: Words.helpBackground }] : [],
    island.plugin?.recalls ? [{ key: "Ctrl+r", desc: Words.helpRecall }] : [],
    [{ key: "Escape", desc: Words.helpEscape }]
  )
  readonly property bool slashFilters: !!level?.entry?.list && !find(items, "/")
  readonly property int unhidden: levelList.filter(item => !item.hidden).length
  readonly property var hints: held === "Help" ? help : held === "Ctrl" ? barItems.filter(item => item.key).map(item => hint(item, MenuKeys.names(item.key).map(name => "Ctrl+" + name)))
    : held === "Super" ? barItems.filter(item => shortcutOf(item)).map(item => hint(item, shortcutOf(item))) : []
  // Only keys the state changes; fixed ones are listed on `?`.
  readonly property var levelLegend: (viewModel ? viewModel.legend : Lists.builtin[level?.entry?.list]?.legend ?? [])
    .concat(slashFilters && unhidden > 9 ? [{ key: "/", what: Words.shownOf(unhidden), clickable: true }] : [])
  readonly property var legend: filtering ? filter.legend : levelLegend
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

  // "body", "input" (the level input) or "answer" (the turn over it).
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
  }

  function back() {
    const left = level;
    stack = stack.slice(0, -1);
    stopFilter();
    internal.focus = left?.inputFocused ? "input" : "body";
    clearViews();
  }

  function push(next) {
    stack = stack.concat([Object.assign({}, next, { inputFocused: inputFocused })]);
    stopFilter();
    internal.focus = "body";
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
      action.run(second === 1, list, root);
      return;
    }
    const cmd = MenuKeys.isPair(entry) ? Array.from(entry.cmd)[MenuKeys.names(entry.key).indexOf(name)] : entry.cmd;
    // No command: an entry showing a plugin activates it, as a click on it in a bar does.
    if (!cmd) return Plugins.get(entry.status ?? "")?.activate();
    if (!entry.keepOpen) hide();
    Commands.run(cmd);
  }

  function startFilter() {
    if (!level?.entry?.list) return;
    filterSlots = Math.max(1, rows.length);
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

  // Escape once the input is cleared.
  function stepBack() {
    if (filtering && !level.picking) return stopFilter();
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

  function activate(item, name) {
    if (item.enabled === false) return;
    // A tray app that only offers a menu does nothing when activated (Quickshell's onlyMenu).
    if (item.app?.onlyMenu) return openMenu(item);
    if (item.select) {
      if (item.closes) hide();
      item.select();
    } else if (!item.entry) {
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

  // The wheel: a listed item adjusts itself; an entry runs its own row on that key (volume).
  function act(item, name) {
    if (item.adjust) return item.adjust(name === "Up");
    const action = item.entry?.submenu ? find(Array.from(item.entry.submenu), name) : MenuKeys.matches(item.entry?.key ?? [], name) ? item.entry : null;
    if (action && available(action)) run(action, name);
  }

  // Escape and Tab are kept free by Validation.
  function handleKey(event) {
    // A bare modifier has no name, and Super belongs to the compositor.
    if (event.modifiers & Qt.MetaModifier) return false;
    // A held key repeats on the level it was pressed on, never into the one it opened.
    if (event.isAutoRepeat && level !== internal.pressedOn) return true;
    if (!event.isAutoRepeat) internal.pressedOn = level;
    return handleName(MenuKeys.name(event));
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
    else if (answerFocused && island.answerKey(name)) return true;
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
    stack = [];
    if (!open) show();
    for (const [i, name] of path.trim().split(/\s+/).entries()) {
      // A key that closed the menu ends the path, so none past it opens a level on the closed menu.
      if (i > 0 && !inStack) return false;
      if (!(filtering ? filterKey(name) : handleName(name))) return false;
    }
    base = stack.length;
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
  }
}
