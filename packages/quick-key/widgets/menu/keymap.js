.pragma library

// The menu's one key map, pure: a binding per key on screen, which a key reaches from anywhere, `?` lists and the check refuses twice.
// A binding: { key, island, what: its handler, desc: on `?`, label: its holder, for the check, item: the row it runs, name: a bar key's own, cursor: no key path's }.
// An island: { name, items, pins: [{ key, desc }], view: [{ key, desc, label }], more: `0`, filters: `/`, focused: has the cursor, and then
// free: the arrows it takes, content, cursorItem: the row Return runs }.

// Keys of the island with the cursor alone: a view's too.
const cursorKeys = ["Up", "Down", "Left", "Right", "Return", "Alt+Return"];

function names(key) {
  return (typeof key === "string" ? [key] : Array.from(key ?? [])).filter(name => typeof name === "string" && name !== "");
}

function hasMenu(item) {
  return item?.actions?.length > 0 || !!item?.app?.hasMenu;
}

// At rest: `?`, each view's keys, the holds `?` lists, every island's rows and pins, the bar's with Ctrl, the cursor, item menus, `0`, `/`, Tab, Escape. Where two may meet, the first wins: a view before rows, rows before the bar and the cursor.
// `at`: { islands, bar: its items, holds: { Ctrl, Super } while each lists something, tab: an input to go to, words: Words }.
function rest(at) {
  const out = [];
  const add = (key, island, what, more) => out.push(Object.assign({ key, island, what }, more));
  const words = at.words ?? {};
  const islands = Array.from(at.islands ?? []);
  const focused = islands.find(island => island.focused);
  add("?", "", "help");
  for (const island of islands)
    for (const entry of island.view ?? [])
      for (const key of names(entry.key)) if (island.focused || !cursorKeys.includes(key)) add(key, island.name, "view", { desc: entry.desc, label: entry.label });
  if (at.holds?.Ctrl) add("Ctrl+", "", "hold", { desc: words.helpBarKeys });
  if (at.holds?.Super) add("Super+", "", "hold", { desc: words.helpCompositor });
  for (const island of islands) {
    // A content island's actions sit on the bar only while it has the cursor: `?` lists them otherwise.
    const unshown = item => !island.focused && island.content && !item.listed;
    for (const item of island.items ?? []) for (const key of names(item.key)) add(key, island.name, "row", { item, label: item.desc, desc: unshown(item) ? item.desc : undefined });
    for (const pin of island.pins ?? []) add(pin.key, island.name, "pin", { label: pin.desc, desc: pin.desc });
  }
  out.push(...barred(at.bar));
  if (focused?.free?.length) {
    for (const key of focused.free) add(key, focused.name, "cursor", { desc: words.helpMove, cursor: true });
    add("Return", focused.name, "return", { item: focused.cursorItem ?? null, desc: focused.content ? undefined : words.helpRun, cursor: true });
  }
  if (focused && hasMenu(focused.cursorItem)) add("Alt+Return", focused.name, "itemMenu", { item: focused.cursorItem, cursor: true });
  let menus = 0;
  for (const island of islands)
    for (const item of island.items ?? []) if (/^[0-9]$/.test(item.key) && hasMenu(item)) add("Alt+" + item.key, island.name, "itemMenu", { item, desc: menus++ ? undefined : words.helpItemMenu });
  for (const island of islands) {
    if (island.more) add("0", island.name, "more");
    if (island.filters) add("/", island.name, "filter", { desc: words.helpFilter });
  }
  if (at.tab) {
    add("Tab", "", "tab", { desc: words.helpTab, step: 1 });
    add("Backtab", "", "tab", { step: -1 });
  }
  add("Escape", "", "back", { desc: words.helpEscape });
  return out;
}

// The bar's keys, with Ctrl wherever the keys are: its entries, and a listed item's own menu with Alt too.
function barred(bar) {
  const out = [];
  for (const item of bar ?? []) {
    for (const name of names(item.key)) out.push({ key: "Ctrl+" + name, island: "bar", what: "bar", item, name, label: item.desc });
    if (/^[0-9]$/.test(item.key) && hasMenu(item)) out.push({ key: "Ctrl+Alt+" + item.key, island: "bar", what: "itemMenu", item });
  }
  return out;
}

// Filtering: the digits pick the rows shown and never type, the arrows move the filter's cursor, Return picks its row. `at`: { island, rows, item, size, bar }.
function filtering(at) {
  const out = [];
  const add = (key, what, more) => out.push(Object.assign({ key, island: at.island, what }, more));
  for (let i = 1; i <= 9; i++) {
    add(String(i), "choose", { item: at.rows[i - 1] });
    add("Alt+" + i, "itemMenu", { item: at.rows[i - 1] });
  }
  add("Return", "choose", { item: at.item });
  add("Alt+Return", "itemMenu", { item: at.item });
  for (const [key, by] of [["Up", -1], ["Down", 1], ["Page_Up", -at.size], ["Page_Down", at.size]]) add(key, "move", { by });
  out.push(...barred(at.bar));
  add("Escape", "back");
  return out;
}

// Typing: every key is the input's but what leaves it and the bar's; Return and C-S-RET are the input's own, listed on `?`. `at`: { tab: an input to type in, recalls, bar, words }.
function typing(at) {
  const words = at.words ?? {};
  const out = [];
  const add = (key, what, more) => out.push(Object.assign({ key, island: "", what }, more));
  if (at.tab) {
    add("Tab", "tab", { step: 1, desc: words.helpTab });
    add("Backtab", "tab", { step: -1 });
    add("Ctrl+Shift+Return", "send", { desc: words.helpSendLeave });
  }
  if (at.tab && at.recalls) add("Ctrl+r", "recall", { desc: words.helpRecall });
  out.push(...barred(at.bar));
  add("Escape", "back", { desc: words.helpEscape });
  return out;
}

// While `?` lists the keys: any key closes it.
function helping() {
  return [{ key: "*", island: "", what: "closeHelp" }];
}

// The binding a key name reaches, null for none: the first, as the check leaves one per key.
function route(bindings, name) {
  if (!name) return null;
  return bindings.find(binding => binding.key === name || binding.key === "*") ?? null;
}

// What `?` lists: each described binding once, in order, the keys sharing a description as one (the arrows, a pair).
function help(bindings) {
  const out = [];
  for (const binding of bindings) {
    if (!binding.desc) continue;
    const same = out.find(entry => entry.desc === binding.desc);
    if (!same) out.push({ key: binding.key, desc: binding.desc, paired: false });
    else if (!names(same.key).includes(binding.key)) Object.assign(same, { key: names(same.key).concat(binding.key), paired: true });
  }
  return out;
}

// Each key two bindings hold, with both: what the check refuses.
function overlaps(bindings) {
  const by = new Map();
  for (const binding of bindings) by.set(binding.key, (by.get(binding.key) ?? []).concat([binding]));
  return Array.from(by).filter(([, held]) => held.length > 1).map(([key, held]) => ({ key, held }));
}

// The keys a level of the config puts on screen at once, for the check: its rows and its view's keys, each pinned entry's rows, list digits and view keys, the bar's with Ctrl.
// `level`: { entries, pinned: the keys its layout pins, bar: its bar's entries, view, list }; `views`: each view by name, its `keys` (Views.builtin).
function ofLevel(level, views) {
  const entries = Array.from(level.entries ?? []).filter(entry => entry && typeof entry === "object");
  const pinned = [...new Set(level.pinned ?? [])];
  const viewOf = name => Array.from(views[name]?.keys ?? []).map(entry => ({ key: entry.key, label: "the " + name + " view" }));
  const pins = pinned.map(key => entries.find(entry => entry.key === key)).filter(entry => entry);
  const digits = (list, limit, desc) => list ? Array.from({ length: Math.min(9, limit ?? 9) }, (_, i) => ({ key: String(i + 1), desc })) : [];
  const rows = entry => Array.from(entry.submenu ?? []).filter(row => row && typeof row === "object").concat(digits(entry.list, entry.limit, entry.desc));
  // Its own list's digits only beside a pin: a row of its own on a digit is its entry's problem ("binds a digit").
  const body = entries.filter(entry => !pins.includes(entry)).concat(pins.length ? digits(level.list, 9, level.list) : []);
  const islands = [{ name: "body", focused: true, items: body, pins: pins.map(entry => ({ key: entry.key, desc: entry.desc })), view: viewOf(level.view) }]
    .concat(pins.map(entry => ({ name: entry.key, items: rows(entry), view: viewOf(entry.view) })));
  return rest({ islands, bar: Array.from(level.bar ?? []).filter(entry => entry && typeof entry === "object") })
    .filter(binding => ["view", "row", "pin", "bar"].includes(binding.what));
}
