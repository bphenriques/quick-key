import QtQuick
import qs
import qs.services
import qs.builtins

// The bar (docs/src/menu.md#bars): its slots, the keys it takes with Ctrl and what its left shows; the menu keeps which island has the cursor.
QtObject {
  id: root

  required property MenuModel menu

  readonly property var top: ({ left: Config.barSlot("left"), center: Config.barSlot("center"), right: Config.barSlot("right") })
  // The body's level's, which Ctrl reaches wherever the cursor is: what the bar draws follows the cursor, its keys never.
  readonly property var keyed: itemsOf(slotsAt(menu.body))
  // The cursor island's bar, as the input is its input: its actions and legend, then its level's slots, a pinned level having none.
  readonly property var slots: slotsAt(menu.focused)
  readonly property var items: itemsOf(slots)
  // Its left: the cursor island's actions and legend, then what Return runs there, so the other islands' keys act unlisted (`?` lists them); filtering, the filter's keys alone.
  readonly property var actions: menu.focused.barActions.map(item => ({ item, model: menu.focused }))
  readonly property var legend: legendOf(menu.focused)
  // Nothing to show for any island the cursor may be on, so its moving never adds or removes it: it then shows empty, unless farthest from the edge (Places.shown).
  readonly property bool empty: keyed.length === 0 && items.length === 0 && menu.shown.every(model => model.barActions.length === 0 && legendOf(model).length === 0)

  function legendOf(model) {
    return model.filtering ? model.legend : model.levelLegend.filter(key => menu.owns(model, key.key)).concat(model.cursorLegend);
  }

  // The slots of an island's level's bar: the top's, an entry's `bar`, an app menu's own.
  function slotsAt(model) {
    return model.level === null ? slotsOf(top) : model.kinds[model.level.kind].bar(model.level);
  }

  function slotsOf(bar) {
    return { left: barOf(bar.left), center: barOf(bar.center), right: barOf(bar.right) };
  }

  function itemsOf(slots) {
    return slots.left.concat(slots.center, slots.right);
  }

  // A name is a status or plugin to show, an entry with a list and no key each of its items; `uid` is what the view follows an item by.
  function barOf(slot) {
    return Array.from(slot ?? []).reduce((items, part) => items.concat(typeof part === "string" ? [{ key: "", desc: part, status: part, uid: part }]
      : part.list && !part.key ? barList(part).map(item => Object.assign({}, item, { uid: part.list + ":" + (item.id ?? "more") }))
      : [Object.assign(menu.body.itemOf(part), { uid: part.key || part.desc })]), []);
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
    const all = Lists.items(entry.list, entry.hide);
    const shown = menu.body.numbered(entry.list, entry.pins, all).slice(0, entry.limit ?? 9);
    const onBar = shown.map(item => item.id);
    const more = all.filter(item => !item.hidden && !onBar.includes(item.id)).length;
    return more > 0 ? shown.concat({ key: "0", desc: "+" + more, select: () => menu.pickList(entry.list, entry.hide) }) : shown;
  }
}
