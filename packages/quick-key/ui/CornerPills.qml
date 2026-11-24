pragma Singleton

import QtQuick
import Quickshell

// The corner pills on screen, in the order they showed, so each stacks under those before it.
Singleton {
  property var order: []

  // Where a pill starts below the first: the height of those before it.
  function offset(pill) {
    return order.slice(0, Math.max(0, order.indexOf(pill))).reduce((sum, each) => sum + each.height, 0);
  }

  function add(pill) {
    if (!order.includes(pill)) order = order.concat([pill]);
  }

  function remove(pill) {
    order = order.filter(each => each !== pill);
  }
}
