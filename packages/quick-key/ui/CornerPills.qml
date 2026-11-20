pragma Singleton

import QtQuick
import Quickshell

// The corner pills on screen, in the order they showed, so each stacks under those before it.
Singleton {
  property var order: []

  function add(pill) {
    if (!order.includes(pill)) order = order.concat([pill]);
  }

  function remove(pill) {
    order = order.filter(each => each !== pill);
  }
}
