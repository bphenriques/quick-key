import QtQuick
import qs.ui

// A level's list filtered in place (`/`): the items whose label holds every word typed, nine rows on digits that follow them, and a cursor that stays on its item as the list changes.
QtObject {
  id: root

  // In the level's order, hidden ones too: a word typed finds them.
  property var items: []
  property string query: ""
  // The item the cursor is on, by id, and the first row shown.
  property string current: ""
  property int offset: 0

  // The rows it shows at a time: the level's own at rest, so its body keeps its height.
  property int size: 9
  // Lowercased once per change of the list, not per key.
  readonly property var labels: items.map(item => (item.desc ?? "").toLowerCase())
  readonly property var words: query.toLowerCase().split(/\s+/).filter(word => word !== "")
  readonly property var found: words.length === 0 ? items.filter(item => !item.hidden) : items.filter((item, i) => root.words.every(word => root.labels[i].includes(word)))
  readonly property int index: Math.max(0, found.findIndex(item => item.id === current))
  readonly property var item: found[index] ?? null
  // Clamped, so a list that shrinks keeps its rows filled.
  readonly property int first: Math.max(0, Math.min(offset, found.length - size))
  readonly property var rows: found.slice(first, first + size).map((item, i) => Object.assign({}, item, { key: String(i + 1), listed: true, current: first + i === index }))
  // The rows shown of all that match, as a pager says it (1-9 of 11).
  readonly property string count: found.length === 0 ? "" : (rows.length > 1 ? (first + 1) + "-" + (first + rows.length) : String(first + 1)) + " of " + found.length
  readonly property string emptyText: items.length > 0 && found.length === 0 ? Words.noMatch(query.trim()) : ""
  // Only what the state changes; Escape last, so its changing word moves nothing.
  readonly property var legend: (rows.length > 0 ? [{ key: rows.length > 1 ? "1-" + rows.length : "1", what: Words.choose }, { key: ["Up", "Down"], what: Words.move }] : [])
    .concat(item ? [{ key: "Return", what: item.verb || Words.pick, clickable: true }] : [])
    .concat(item?.actions?.length > 0 ? [{ key: "Alt+Return", what: Words.menu, clickable: true }] : [])
    .concat([{ key: "Escape", what: query ? Words.clear : Words.back, clickable: true }])

  onQueryChanged: {
    current = "";
    offset = 0;
  }

  function reset() {
    query = "";
    current = "";
    offset = 0;
  }

  // The cursor by `by` rows, the rows shown following it.
  function move(by) {
    if (found.length === 0) return;
    const next = Math.max(0, Math.min(found.length - 1, index + by));
    current = found[next].id;
    offset = next < first ? next : next >= first + size ? next - size + 1 : first;
  }
}
