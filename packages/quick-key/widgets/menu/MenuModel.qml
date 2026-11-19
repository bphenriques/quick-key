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
  // What lists keys in place of the body: "Ctrl" or "Super" held a second (not at once, so a chord does not flash them), or "Help" after `?`.
  property string held: ""
  // Whether the level's input has the keys, else its body.
  property bool inputFocused: false
  // Whether Tab moved the keys on to the answer over the input, where Return opens the plugin's panel.
  property bool answerFocused: false
  // Each input's unsent text, by the input, kept as the menu closes, as Ask keeps its draft.
  property var drafts: ({})
  readonly property string draft: draftOf(input)
  readonly property CalendarModel calendar: CalendarModel {}

  readonly property var entries: Array.from(Config.menu.entries ?? Config.starterEntries)
  readonly property var level: stack[stack.length - 1] ?? null
  readonly property bool inCalendar: level?.entry?.view === "calendar"
  // The text a level takes under its body (an entry's `input`, or `menu.input` at the top level): { desc, cmd, plugin, format, after }.
  readonly property var input: level === null ? Config.menu.input ?? null : level.kind === "entry" ? level.entry.input ?? null : null
  // The plugin an input without a `cmd` gives its text: its own, else the one the level lists.
  readonly property var inputPlugin: input && !input.cmd ? Plugins.get(input.plugin ?? level?.entry?.list ?? "") : null
  readonly property bool inputBusy: inputPlugin?.busy ?? false
  // The plugin and the input on show, so an answer shows there; a change of either ends a visit. Expanded into the plugin's panel, the visit holds.
  readonly property string inputToken: inputPlugin ? inputPlugin.name + "\n" + JSON.stringify(input) : ""
  property string expandedWatching: ""
  // What Plugins.watching is set to.
  readonly property string watching: open ? inputToken : expandedWatching
  // The turn of the conversation the input started (Plugin.turn), its options a digit picks until Escape sets them aside.
  readonly property var turn: inputPlugin?.turn ?? null
  readonly property var choices: turn?.options ?? []
  property bool choicesAside: false
  onTurnChanged: {
    choicesAside = false;
    if (!turn) answerFocused = false;
  }
  // The text last sent, which a failed turn gives back to the input.
  property string lastSent: ""
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
  // The keys no row shows, listed on `?`: holds, an item's own menu, back and close.
  readonly property var help: [
    { key: "Ctrl+", desc: "Hold: the bar's keys" },
    { key: "Super+", desc: "Hold: compositor shortcuts" },
    { key: "Alt+1", desc: "An item's own menu" }
  ].concat(input ? [{ key: "Tab", desc: "The input, and back" }, { key: "Ctrl+Shift+Return", desc: "Send in the background" }] : [], [
    { key: "BackSpace", desc: "Back" },
    { key: "Escape", desc: "Close" }
  ])
  // The keys listed in place of the body: the help, the bar's while Ctrl is held, the compositor's while Super is.
  readonly property var hints: held === "Help" ? help : held === "Ctrl" ? barItems.filter(item => item.key).map(item => hint(item, "Ctrl+" + item.key))
    : held === "Super" ? barItems.filter(item => shortcutOf(item)).map(item => hint(item, shortcutOf(item))) : []
  // Keys a level takes beyond its rows, shown in its body (KeyLegend): { key, what }, only what the state changes (fixed keys are `?`'s); while its input has the keys, its Escape, in a level that has a legend.
  readonly property var levelLegend: inCalendar ? calendar.legend : Lists.builtin[level?.entry?.list]?.legend ?? []
  readonly property var legend: inputFocused && levelLegend.length > 0 ? [{ key: "Escape", what: draft ? Words.clear : Words.back, clickable: true }] : levelLegend
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

  // Pins first, each keeping its digit, dimmed while what it matches is absent; the rest follow in the list's order, a hidden one only in the picker.
  function numbered(list, pins, items = listed(list)) {
    const rest = Array.from(items).filter(item => !item.hidden);
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
      hidden: item.hidden ?? false,
      busy: item.busy ?? false,
      glyphs: Array.from(item.glyphs ?? []),
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
    answerFocused = false;
  }

  // A level starts with no event in focus, coming back to it too.
  function back() {
    stack = stack.slice(0, -1);
    inputFocused = false;
    answerFocused = false;
    calendar.focused = "";
  }

  function push(next) {
    stack = stack.concat([next]);
    inputFocused = false;
    answerFocused = false;
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

  // The input's text, to its command as $1, else its plugin; whether it was taken, so the input keeps it if not.
  function submit(text, background) {
    text = text.trim();
    if (!text || !input || inputBusy) return false;
    // The format wraps what starts a conversation; once the plugin has answered, the next send answers it as typed.
    const sent = input.format && (!turn || turn.phase === "failed") ? input.format.replace(/\{text\}/g, () => text) : text;
    if (input.cmd) Commands.runThen(input.cmd, input.after ?? "", sent);
    // A plugin that failed to load takes nothing.
    else if (!inputPlugin || inputPlugin.submit(sent, background, input.after ?? "") === false) return false;
    lastSent = text;
    if (background) hide();
    return true;
  }

  // An option of the answer, sent as the next message.
  function pick(index) {
    const option = choices[index];
    return option !== undefined && !choicesAside && submit(option, false);
  }

  // The plugin's own panel on the conversation; stepping back from it shows this level again, the visit going on, and leaving it otherwise ends the visit.
  function expand() {
    const saved = stack.slice();
    expandedWatching = inputToken;
    const opened = inputPlugin?.expand(returning => {
      if (returning) {
        stack = saved;
        show();
        inputFocused = true;
      }
      expandedWatching = "";
    });
    if (!opened) expandedWatching = "";
  }

  // A turn the island cannot hold opens the plugin's panel by itself, as a popup does: once, so coming back does not open it again.
  property var expandedTurn: null
  function overflowed() {
    if (turn === expandedTurn || turn?.phase === "working") return;
    expandedTurn = turn;
    expand();
  }

  // Keys while the answer has them: Return opens the plugin's panel, y copies the answer, Tab and Escape give them to the body, Shift+Tab back to the input.
  function answerKey(name) {
    if (name === "Return") expand();
    else if (name === "y") Quickshell.clipboardText = turn?.text ?? "";
    else if (name === "Tab" || name === "Escape") answerFocused = false;
    else if (name === "Backtab") {
      answerFocused = false;
      inputFocused = true;
    } else return false;
    return true;
  }

  function draftOf(of) {
    return of ? drafts[JSON.stringify(of)] ?? "" : "";
  }

  function keepDraft(text) {
    if (input && text !== draft) drafts = Object.assign({}, drafts, { [JSON.stringify(input)]: text });
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
    // Any key closes the help, which only lists keys.
    if (held === "Help") held = "";
    else if (name === "?") held = "Help";
    else if (answerFocused && answerKey(name)) return true;
    else if (name === "Escape") hide();
    else if (inCalendar && calendar.handleKey(name)) return true;
    else if (name === "BackSpace" && level) back();
    else if (input && name === "Tab") inputFocused = true;
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
