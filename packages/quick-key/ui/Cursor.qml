import QtQuick
import "cursor.js" as Steps

// The row the arrows are on, by id, over rows laid out row-major in `columns`; its owner says what Return runs.
QtObject {
  id: root

  // An id per row, in their order.
  property var ids: []
  property int columns: 1
  // The arrows it takes, those its owner leaves free.
  property var free: []
  // Where the first arrow moves from (the item in use), else it lands on the first row or the last.
  property var from: undefined
  // Its row's id: none until an arrow moves it, or once its row leaves.
  readonly property var current: ids.includes(internal.at) ? internal.at : undefined

  // Whether the key moved it.
  function key(name) {
    const next = Steps.next(ids.length, columns, ids.indexOf(current ?? from), name, free);
    if (next >= 0) internal.at = ids[next];
    return next >= 0;
  }

  // Whether ↑ or ↓ would leave its rows.
  function atEdge(name) {
    return Steps.atEdge(ids.length, columns, ids.indexOf(current), name);
  }

  // Onto a row, or none (undefined).
  function point(id) {
    internal.at = id;
  }

  readonly property QtObject internal: QtObject {
    property var at: undefined
  }
}
