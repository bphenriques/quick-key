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

  property bool open: false
  // Levels opened below the top one, the last is shown: an entry's (kind "entry") or an app's own menu (kind "menu").
  property var stack: []
  // The modifier held a second, whose keys show: "Ctrl" the bar's, "Super" the compositor's; not at once, so a chord does not flash them.
  property string held: ""
  // Whether the level's input has the keys, else its body.
  property bool inputFocused: false
  readonly property CalendarModel calendar: CalendarModel {}

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  readonly property var level: stack[stack.length - 1] ?? null
  readonly property bool inCalendar: level?.entry?.view === "calendar"
  // The text a level takes under its body (an entry's `input`): { key, desc, cmd }.
  readonly property var input: level?.kind === "entry" ? level.entry.input ?? null : null
  // What the level lists, read once for every entry that acts on it.
  readonly property var levelList: listed(level?.entry?.list)
  readonly property var items: itemsOf(level)
  readonly property var actions: items.filter(item => !item.listed)
  readonly property var rows: items.filter(item => item.listed)
  readonly property int width: level?.width ?? Config.menu.width
  // Why a level's list is empty, in its place; "" while it lists something.
  readonly property string emptyText: level?.entry?.list && rows.length === 0 ? Lists.builtin[level.entry.list]?.empty() ?? Plugins.get(level.entry.list)?.empty ?? "" : ""
  readonly property var topBar: ({ left: Config.headerSlot("left"), center: Config.headerSlot("center"), right: Config.headerSlot("right") })
  // The level's bar by slot: the top level's is menu.header, else the starter's, an entry's its own `header`, an app's menu the app and the way into it (blueman › Plugins).
  readonly property var bar: level === null ? topBar
    : level.kind === "entry" ? level.entry.header ?? {} : {}
  readonly property var barSlots: level?.kind === "menu" ? { left: [appOf(stack.filter(level => level.kind === "menu"))], center: [], right: [] }
    : { left: barOf(bar.left), center: barOf(bar.center), right: barOf(bar.right) }
  readonly property var barItems: barSlots.left.concat(barSlots.center, barSlots.right)
  // While Ctrl is held a second, the bar's keys in place of the body, each named; while Super is, the compositor's.
  readonly property var hints: held === "Ctrl" ? barItems.filter(item => item.key).map(item => hint(item, "Ctrl+" + item.key))
    : held === "Super" ? barItems.filter(item => shortcutOf(item)).map(item => hint(item, shortcutOf(item))) : []
  // Keys a level takes beyond its rows, shown in its body (KeyLegend): { key, what }.
  readonly property var legend: inCalendar ? calendar.legend : Lists.builtin[level?.entry?.list]?.legend ?? []
  // Why a level's source failed, under its keys: the calendar's sync, or the plugin it lists.
  readonly property string error: inCalendar ? (Calendar.syncing ? "" : Calendar.error) : Plugins.get(level?.entry?.list ?? "")?.error ?? ""

  // An entry as a row or a bar item shows it.
  function itemOf(entry) {
    const action = Actions.builtin[entry.action];
    return {
      key: entry.key ?? "",
      desc: entry.desc,
      status: entry.status ?? "",
      format: entry.format ?? "",
      icon: entry.icon ?? (action ? action.icon() : ""),
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
    return Object.assign({}, item, { key, status: "", format: "", paired: false, icon: item.icon || (item.image ? "" : glyph) });
  }

  // An app's menu as its bar shows it: the app's icon, and its name with the submenus opened since.
  function appOf(menus) {
    return { key: "", desc: menus.map(menu => menu.title).join(" › "), image: menus[0]?.image ?? "", named: true };
  }

  // A list in a bar: its `limit` (at most nine) on digits, then 0 for the whole list in the picker when there are more.
  function barList(entry) {
    const all = listed(entry.list);
    const shown = numbered(entry.list, entry.pins, all).slice(0, entry.limit ?? 9);
    const more = all.length - shown.length;
    return more > 0 ? shown.concat({ key: "0", desc: "+" + more, enabled: Config.menu.picker !== "", closes: true, select: () => Picker.pick(all) }) : shown;
  }

  // Pins first, each keeping its digit, dimmed while what it matches is absent; the rest follow in the list's order.
  function numbered(list, pins, items = listed(list)) {
    const rest = Array.from(items);
    const pinned = Array.from(pins ?? []).map(pin => {
      const index = rest.findIndex(item => MenuKeys.glob(pin.match, item.id));
      if (index < 0) return { desc: pin.label, icon: pin.icon ?? Lists.builtin[list]?.icon ?? Glyphs.tray, enabled: false };
      const item = rest.splice(index, 1)[0];
      return Object.assign({}, item, { desc: pin.label, icon: pin.icon ?? item.icon });
    });
    return pinned.concat(rest).slice(0, 9).map((item, i) => Object.assign({}, item, { key: String(i + 1), listed: true }));
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
      meter: item.meter,
      active: item.active ?? false,
      enabled: item.enabled ?? true,
      done: item.done ?? false,
      tone: item.tone ?? "",
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
    return Actions.builtin[entry.action]?.available(levelList) ?? true;
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
  }

  function hide() {
    open = false;
    stack = [];
    held = "";
    inputFocused = false;
  }

  // A level starts with no event in focus, coming back to it too.
  function back() {
    stack = stack.slice(0, -1);
    inputFocused = false;
    calendar.focused = "";
  }

  function push(next) {
    stack = stack.concat([next]);
    inputFocused = false;
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
      // Read before hide(), which leaves the level.
      const list = levelList;
      if (entry.keepOpen === false || action.closes) hide();
      action.run(second === 1, list);
      return;
    }
    const cmd = MenuKeys.isPair(entry) ? Array.from(entry.cmd)[MenuKeys.names(entry.key).indexOf(name)] : entry.cmd;
    if (!cmd) return;
    if (!entry.keepOpen) hide();
    Commands.run(cmd);
  }

  // The input's text, to its command as $1 or else to the plugin the level lists.
  function submit(text) {
    text = text.trim();
    if (!text || !input) return;
    if (input.cmd) Commands.run(input.cmd, text);
    else Plugins.get(level.entry.list)?.submit(text);
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

  // A tray app's own menu: Alt with its digit, or a right click.
  function openMenu(item) {
    if (item?.app?.hasMenu) push({ kind: "menu", title: item.desc, image: item.image ?? "", handle: item.app.menu, width: width });
  }

  // The mouse wheel on a row: a pair runs itself; an entry runs the action of its own on that key, e.g. volume.
  function act(item, name) {
    const action = item.entry?.submenu ? find(Array.from(item.entry.submenu), name) : MenuKeys.matches(item.entry?.key ?? [], name) ? item.entry : null;
    if (action && available(action)) run(action, name);
  }

  // The body's keys first, then Alt for an item's own menu and Ctrl for the bar (with Alt, a bar item's own menu); Esc and Backspace are kept free by the check.
  function handleKey(event) {
    const name = MenuKeys.name(event);
    // A modifier on its own has no name, and Super belongs to the compositor: a chord with it runs nothing here.
    if (!name || event.modifiers & Qt.MetaModifier) return false;
    const [, ctrl, alt, key] = name.match(/^(Ctrl\+)?(Alt\+)?(.*)$/);
    const own = find(items, name);
    const target = alt && /^[0-9]$/.test(key) ? find(ctrl ? barItems : rows, key) : null;
    const barred = ctrl && !alt ? find(barItems, key) : null;
    if (name === "Escape") hide();
    else if (inCalendar && calendar.handleKey(name)) return true;
    else if (name === "BackSpace" && level) back();
    else if (input && MenuKeys.matches(input.key, name)) inputFocused = true;
    else if (own) activate(own, name);
    else if (target) openMenu(target);
    else if (barred) activate(barred, key);
    else return false;
    return true;
  }

  QsMenuOpener {
    id: menuOpener
    menu: root.level?.kind === "menu" ? root.level.handle : null
  }
}
