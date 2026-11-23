pragma Singleton

import QtQuick
import Quickshell
import qs

// The corner pills on screen, in the order they showed, so each stacks under those before it.
Singleton {
  property var order: []
  // The stack's height, each pill as tall as it draws and a gap after it, so what sits under it (the cards) starts below.
  readonly property real height: order.reduce((sum, pill) => sum + pill.height + Config.theme.spacing, 0)

  // Where a pill starts below the first: the height of those before it.
  function offset(pill) {
    return order.slice(0, Math.max(0, order.indexOf(pill))).reduce((sum, each) => sum + each.height + Config.theme.spacing, 0);
  }

  function add(pill) {
    if (!order.includes(pill)) order = order.concat([pill]);
  }

  function remove(pill) {
    order = order.filter(each => each !== pill);
  }
}
