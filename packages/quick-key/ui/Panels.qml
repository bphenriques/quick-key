pragma Singleton

import QtQuick
import Quickshell

// The surfaces the keyboard opens, as one stack of their owners (the menu, a plugin): the top one shows, opening one covers the one under it, stepping back shows that one again, and closing hides them all. Also the top level's right slot, which the menu registers for a plugin's panel's bar.
Singleton {
  property var stack: []
  readonly property var top: stack[stack.length - 1] ?? null
  property Component statuses: null

  // Shows `owner` on top: over the others, or back on top, closing what covered it.
  function open(owner) {
    const at = stack.indexOf(owner);
    stack = at < 0 ? stack.concat([owner]) : stack.slice(0, at + 1);
  }

  // Closes the top, showing the one under it again.
  function back() {
    stack = stack.slice(0, -1);
  }

  function close() {
    stack = [];
  }

  // Takes `owner` out of the stack wherever it is, as when it opens again on top.
  function remove(owner) {
    stack = stack.filter(each => each !== owner);
  }
}
