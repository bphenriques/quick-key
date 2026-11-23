import QtQuick
import qs.ui

// A level's list filtered in place (`/`): the items whose label holds every word typed, nine rows on digits that follow them, and a cursor that stays on its item as the list changes.
QtObject {
  id: root

  // In the level's order, hidden ones too: a word typed finds them.
  property var items: []
  // What is typed, the item the cursor is on by id, and the first row shown: its own, changed only by its functions.
  readonly property string query: internal.query
  readonly property string current: internal.current
  readonly property int offset: internal.offset

  // The rows it shows at a time: the level's own at rest, so its body keeps its height.
  property int size: 9
  // Lowercased once per change of the list, not per key.
  readonly property var labels: items.map(item => (item.desc ?? "").toLowerCase())
  readonly property var words: query.toLowerCase().split(/\s+/).filter(word => word !== "")
  readonly property var found: words.length === 0 ? items.filter(item => !item.hidden) : items.filter((item, i) => root.words.every(word => root.labels[i].includes(word)))
  // The cursor's item, else the first row shown, so the cursor never leaves the rows.
  readonly property int index: {
    const at = found.findIndex(item => item.id === current);
    return at >= 0 ? at : first;
  }
  readonly property var item: found[index] ?? null
  // Clamped, so a list that shrinks keeps its rows filled.
  readonly property int first: Math.max(0, Math.min(offset, found.length - size))
  readonly property var rows: found.slice(first, first + size).map((item, i) => Object.assign({}, item, { key: String(i + 1), listed: true, current: first + i === index }))
  // The rows shown of all that match, as a pager says it (1-9 of 11).
  readonly property string count: found.length === 0 ? "" : Words.rangeOf(first, rows.length, found.length)
  readonly property string emptyText: items.length > 0 && found.length === 0 ? Words.noMatch(query.trim()) : ""
  // Only what the state changes, Escape while it clears.
  readonly property var legend: (rows.length > 0 ? [{ key: rows.length > 1 ? "1-" + rows.length : "1", what: Words.choose }, { key: ["Up", "Down"], what: Words.move }] : [])
    .concat(item ? [{ key: "Return", what: item.verb || Words.pick, clickable: true }] : [])
    .concat(item?.actions?.length > 0 ? [{ key: "Alt+Return", what: Words.menu, clickable: true }] : [])
    .concat(query ? [{ key: "Escape", what: Words.clear, clickable: true }] : [])

  // A new search starts at its first row.
  function search(text) {
    internal.query = text;
    internal.current = "";
    internal.offset = 0;
  }

  function reset() {
    search("");
  }

  // The cursor on an item, by its id.
  function point(id) {
    internal.current = id;
  }

  // The cursor by `by` rows, the rows shown following it.
  function move(by) {
    if (found.length === 0) return;
    const next = Math.max(0, Math.min(found.length - 1, index + by));
    internal.current = found[next].id;
    internal.offset = next < first ? next : next >= first + size ? next - size + 1 : first;
  }

  // Its own state, written only by its functions.
  readonly property QtObject internal: QtObject {
    property string query: ""
    property string current: ""
    property int offset: 0
  }
}
