import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.builtins

// What a level shows and does by itself: its items, rows, cursor, filter and legend; the menu keeps its history, bar and keys.
Scope {
  id: root

  required property MenuModel menu
  // A level of the menu's history, null at the top.
  required property var level
  // The island it draws on: the body, or a pin by its key.
  property string island: "body"
  // The most items its list shows on digits: a pin's `limit`.
  property int limit: 9
  readonly property bool focused: menu.focused === root
  // What the input shows while it has the keys: its entry's `input`, `menu.input` at the top level.
  readonly property var input: level === null ? Config.menu.input ?? null : level.entry?.input ?? null

  // Made as a level first shows it, from the file Views names.
  readonly property var viewModel: viewModelOf(level?.entry?.view)
  readonly property var view: viewModel ? Views.builtin[level.entry.view] : null
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
    free: [["Up", "Down"]].concat(root.content ? [] : [["Left", "Right"]]).filter(pair => root.cursorRows.length && !pair.some(key => root.menu.find(root.items, key))).reduce((all, pair) => all.concat(pair), [])
    from: root.content ? root.cursorRows.find(row => row.active)?.id : undefined
  }
  // What Return runs, filtering or at rest.
  readonly property var cursorItem: filtering ? filter.rows.find(row => row.current) ?? null : cursorRows.find(row => idOf(row) === cursor.current) ?? null
  readonly property int width: level?.width ?? Config.menu.width
  // Its body in rows, its entry's `height` else menu.height, a view fitting: the least and the most it holds.
  readonly property var height: level?.entry?.view ? null : level?.entry?.height ?? Config.menu.height
  readonly property int minRows: typeof height === "number" ? height : height?.min ?? 0
  readonly property real maxRows: typeof height === "number" ? height : height?.max ?? Infinity
  // No more columns than its width holds at about twelve characters each.
  readonly property int columns: Math.max(1, Math.min(level?.entry?.columns ?? Config.menu.columns, Math.floor(width / (12 * Metrics.cell))))
  readonly property string emptyText: level?.entry?.list && rows.length === 0 ? (filtering && filter.emptyText) || Lists.empty(level.entry.list) : ""
  // The filter is typed on the input island.
  readonly property bool slashFilters: !!level?.entry?.list && !menu.find(items, "/") && menu.layout.includes("input")
  readonly property int unhidden: levelList.filter(item => !item.hidden).length
  // Past a pin's limit, 0 lists the rest on a level of their own, as a bar's +N does.
  readonly property bool more: limit < 9 && unhidden > limit
  // Only keys the state changes; fixed ones are listed on `?`, and show here too as its entry's `legend` names them.
  readonly property var levelLegend: (viewModel ? viewModel.legend : Lists.builtin[level?.entry?.list]?.legend ?? [])
    .concat(more ? [{ key: "0", what: Words.rangeOf(0, limit, unhidden), clickable: true }]
      : slashFilters && unhidden > 9 ? [{ key: "/", what: Words.shownOf(unhidden), clickable: true }] : [])
    // At the top and on a pin, the key listing the rest, which every surface with such a list shows so.
    .concat((level === null || island !== "body") && Config.menu.keysHint ? [{ key: "?", what: Words.help, clickable: true }] : [])
    .concat(MenuKeys.pick(menu.helpOf(root), level?.entry?.legend))
  readonly property var cursorLegend: (cursorItem && (content || filtering) ? [{ key: returnOf(cursorItem), what: cursorItem.verb || Words.pick, clickable: true }] : [])
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
        bar: level => root.menu.slotsOf(level.entry.bar ?? {}),
        // Own rows by letter (inLevel: a value beside the label, with its meter), then the list by digit.
        items: level => Array.from(level.entry.submenu ?? [])
          .map(entry => Object.assign(root.itemOf(entry), { listed: /^[0-9]$/.test(entry.key), inLevel: true }))
          .concat(root.numbered(level.entry.list, level.entry.pins))
      },
      menu: {
        content: () => false,
        bar: () => ({ left: [root.menu.appOf(root.menu.levels.filter(level => level.kind === "menu"))], center: [], right: [] }),
        items: level => {
          const children = Array.from(menuOpener.children.values).filter(child => !child.isSeparator && child.enabled);
          const labels = children.map(child => child.text.replace(/_/g, ""));
          const keys = MenuKeys.assign(labels);
          return children.map((child, i) => ({
            key: keys[i],
            desc: labels[i],
            glyphs: child.checkState === Qt.Checked ? [Glyphs.check] : child.hasChildren ? [Glyphs.submenu] : [],
            select: child.hasChildren ? () => root.menu.push({ kind: "menu", title: labels[i], handle: child, width: level.width }) : () => {
              // Before hide(), which releases the menu this entry belongs to.
              child.triggered();
              root.menu.hide();
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
              if (!action.closes) root.menu.back();
              action.select();
            }
          }))
      }
    })

  // A pinned entry's row leaves the level declaring the layout for its island.
  function itemsOf(level) {
    const items = level === null ? menu.entries.map(itemOf) : kinds[level.kind].items(level);
    return level === menu.home ? items.filter(item => !item.entry || !menu.pinned.includes(item.entry.key)) : items;
  }

  function viewModelOf(name) {
    if (!name || !Views.builtin[name]) return null;
    if (!internal.viewModels[name]) internal.viewModels[name] = Qt.createComponent(Views.builtin[name].model).createObject(root);
    return internal.viewModels[name];
  }

  function clearViews() {
    for (const model of Object.values(internal.viewModels)) model.clearFocus();
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
    return ordered(list, pins, Array.from(items).filter(item => !item.hidden)).slice(0, limit).map((item, i) => Object.assign({}, item, { key: String(i + 1), listed: true }));
  }

  // A listed item by its id, a row by its first key, else its label.
  function idOf(item) {
    return item.listed ? item.id : MenuKeys.names(item.key ?? "")[0] || item.desc;
  }

  // An island without the keys shows no cursor.
  function marked(item) {
    return focused && item === cursorItem ? Object.assign({ current: true }, item) : item;
  }

  // Actions flow across, so a column is every nth one.
  function columnChars(index, columns) {
    return menu.keyChars(bodyActions.filter((_, i) => i % columns === index % columns));
  }

  // What ends the session takes Shift (rule 6): a row on a capital runs on S-RET alone.
  function returnOf(item) {
    return /^[A-Z]$/.test(item.key) ? "Shift+Return" : "Return";
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

  function startFilter() {
    if (!level?.entry?.list) return;
    filterSlots = Math.max(1, rows.length);
    filter.point(cursor.current ?? "");
    filterOn = true;
  }

  function stopFilter() {
    // At rest, the cursor is on the row the filter's arrows moved to, if any.
    if (filtering) cursor.point(filter.current);
    filterOn = false;
    filter.reset();
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.level?.handle ?? null
  }

  QtObject {
    id: internal
    // By view name, each made on first use.
    property var viewModels: ({})
  }
}
