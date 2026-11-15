import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.builtins
import qs.widgets.menu.calendar

// The menu's state and keys; every level, static or filled at runtime, is a list of items { key, desc, ... }.
Scope {
  id: root

  property bool open: false
  // Levels opened below the top one, the last is shown: an entry's (kind "entry") or an app's own menu (kind "menu").
  property var stack: []
  // Super held a second shows the header's compositor keys, not at once, so a Super shortcut does not flash them.
  property bool shortcutsShown: false
  readonly property CalendarModel calendar: CalendarModel {}

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  readonly property var level: stack[stack.length - 1] ?? null
  readonly property bool inCalendar: level?.entry?.view === "calendar"
  readonly property var items: itemsOf(level)
  readonly property var actions: items.filter(item => !item.listed)
  readonly property var rows: items.filter(item => item.listed)
  readonly property int width: level?.width ?? Config.menu.width
  // Why a level's list is empty, in its place; "" while it lists something.
  readonly property string emptyText: level?.entry?.list && rows.length === 0 ? Lists.builtin[level.entry.list]?.empty() ?? "" : ""
  readonly property string title: inCalendar ? calendar.title : level?.title ?? ""
  // The top-level entry the clock opens.
  readonly property var calendarEntry: itemsOf(null).find(item => item.entry.view === "calendar") ?? null
  // Keys a level takes beyond its rows, shown under the header (KeyLegend): { key, what }.
  readonly property var legend: inCalendar ? calendar.legend : Lists.builtin[level?.entry?.list]?.legend ?? []

  function itemsOf(level) {
    if (level === null)
      return entries.map(entry => ({
        key: entry.key,
        desc: entry.desc,
        status: entry.status ?? "",
        icon: entry.icon ?? Actions.builtin[entry.action]?.icon ?? "",
        enabled: available(entry),
        paired: isPair(entry),
        entry: entry
      }));
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

    // An entry's own rows by letter, then what its list holds by digit.
    const own = Array.from(level.entry.submenu ?? []).map(entry => ({
      key: entry.key,
      desc: entry.desc,
      icon: entry.icon ?? Actions.builtin[entry.action]?.icon ?? "",
      enabled: available(entry),
      paired: isPair(entry),
      active: isOn(entry.activeWhen ?? Actions.builtin[entry.action]?.state),
      listed: /^[0-9]$/.test(entry.key),
      entry: entry
    }));
    return own.concat(numbered(level.entry.list, level.entry.pins));
  }

  // Pins first, each keeping its digit, dimmed while what it matches is absent; the rest follow in the list's order.
  function numbered(list, pins) {
    const rest = listed(list);
    const pinned = Array.from(pins ?? []).map(pin => {
      const index = rest.findIndex(item => MenuKeys.glob(pin.match, item.id));
      if (index < 0) return { desc: pin.label, icon: pin.icon ?? Lists.builtin[list]?.icon ?? Glyphs.tray, enabled: false };
      const item = rest.splice(index, 1)[0];
      return Object.assign(item, { desc: pin.label, icon: pin.icon ?? item.icon });
    });
    return pinned.concat(rest).slice(0, 9).map((item, i) => Object.assign(item, { key: String(i + 1), listed: true }));
  }

  // What a runtime list holds, without keys; each item's id is what pins match.
  function listed(list) {
    if (!list) return [];
    if (Lists.builtin[list]) return Lists.builtin[list].items();
    const plugin = Plugins.get(list);
    return Array.from(plugin?.items ?? []).map(item => ({
      id: item.id,
      desc: item.label ?? item.id,
      icon: item.icon ?? "",
      detail: item.detail ?? "",
      active: item.active ?? false,
      enabled: item.enabled ?? true,
      select: () => plugin.select(item.id)
    }));
  }

  // The widest key of a group of items, in characters.
  function keyChars(group) {
    return Math.max(1, ...group.map(item => MenuKeys.label(item.key, item.paired).length));
  }

  // Actions flow across, so a column is every nth one.
  function columnChars(index, columns) {
    return keyChars(actions.filter((_, i) => i % columns === index % columns));
  }

  // Whether an entry can run now: a command always, an action when it has something to act on.
  function available(entry) {
    return Actions.builtin[entry.action]?.available() ?? true;
  }

  // A pair runs one command or action per key, shown as one row (Down and Up).
  function isPair(entry) {
    return MenuKeys.isPair(entry) || !!Actions.builtin[entry.action]?.pair;
  }

  function isOn(state) {
    const read = States.builtin[state];
    return read ? read() : Plugins.get(state)?.active ?? false;
  }

  function show() {
    // Sources without change events are read as the menu opens.
    Compositor.refresh();
    Plugins.refresh();
    open = true;
  }

  function toggle() {
    if (open) hide();
    else show();
  }

  function toggleEntry(key) {
    const item = find(itemsOf(null), key);
    if (!item) return;
    if (level?.entry === item.entry) {
      hide();
      return;
    }
    stack = [];
    if (!open) show();
    activate(item, key);
  }

  function hide() {
    open = false;
    stack = [];
    shortcutsShown = false;
  }

  // A level starts with no event in focus, coming back to it too.
  function back() {
    stack = stack.slice(0, -1);
    calendar.focused = "";
  }

  function push(next) {
    stack = stack.concat([next]);
    calendar.focused = "";
  }

  function find(candidates, name) {
    return candidates.find(item => MenuKeys.matches(item.key, name));
  }

  // A pair runs the command or action of the key pressed, a click on it nothing; an action keeps the menu open by default.
  function run(entry, name) {
    const action = Actions.builtin[entry.action];
    if (action) {
      const second = MenuKeys.names(entry.key).indexOf(name);
      if (action.pair && second < 0) return;
      if (entry.keepOpen === false) hide();
      action.run(second === 1);
      return;
    }
    const cmd = MenuKeys.isPair(entry) ? Array.from(entry.cmd)[MenuKeys.names(entry.key).indexOf(name)] : entry.cmd;
    if (!cmd) return;
    if (!entry.keepOpen) hide();
    Quickshell.execDetached(["sh", "-c", cmd]);
  }

  // A listed item does what it says; an entry with a level below opens it, any other runs.
  function activate(item, name) {
    if (item.enabled === false) return;
    if (item.select) {
      if (item.closes) hide();
      item.select();
    } else if (item.entry.submenu || item.entry.list || item.entry.view) {
      calendar.reset();
      push({ kind: "entry", title: item.entry.desc, status: item.entry.status, entry: item.entry, width: item.entry.width });
    } else {
      run(item.entry, name);
    }
  }

  // A tray app's own menu: Ctrl with its digit, or a right click.
  function openMenu(item) {
    if (item?.app?.hasMenu) push({ kind: "menu", title: item.desc, handle: item.app.menu, width: level.width });
  }

  // The mouse wheel on a row: a pair runs itself; an entry runs the action of its own on that key, e.g. volume.
  function act(item, name) {
    const action = item.entry?.submenu ? find(Array.from(item.entry.submenu), name) : MenuKeys.matches(item.entry?.key ?? [], name) ? item.entry : null;
    if (action && available(action)) run(action, name);
  }

  // Esc and Backspace are kept free of entries by the check (Validation.qml).
  function handleKey(event) {
    const name = MenuKeys.name(event);
    // A modifier on its own has no name, and Super belongs to the compositor: a chord with it runs nothing here.
    if (!name || event.modifiers & Qt.MetaModifier) return false;
    const item = find(items, name);
    const listed = find(rows, name.replace(/^Ctrl\+/, ""));
    if (name === "Escape") hide();
    else if (inCalendar && calendar.handleKey(name)) return true;
    else if (name === "BackSpace" && level) back();
    else if (name.startsWith("Ctrl+") && listed) openMenu(listed);
    else if (item) activate(item, name);
    else return false;
    return true;
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.level?.kind === "menu" ? root.level.handle : null
  }
}
