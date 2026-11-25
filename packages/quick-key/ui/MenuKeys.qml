pragma Singleton

import QtQuick
import Quickshell
import "keys.js" as Keys

// Keys by their xkb names (a, A, Up, space, ...), as menu entries declare them.
Singleton {
  id: root

  // The name of a key event, Ctrl and Alt first when held (Ctrl+Left); Shift picks the capital letter, or names Shift+Return. "" for a modifier alone.
  function name(event) {
    const key = keyName(event);
    if (!key) return "";
    return (event.modifiers & Qt.ControlModifier ? "Ctrl+" : "") + (event.modifiers & Qt.AltModifier ? "Alt+" : "") + key;
  }

  // How Return sends an input's text: "foreground" plain, "background" with Ctrl+Shift; "" for any other key, Shift+Return breaking the line.
  function sends(event) {
    if (event.key !== Qt.Key_Return && event.key !== Qt.Key_Enter) return "";
    const modifiers = event.modifiers & (Qt.ShiftModifier | Qt.ControlModifier | Qt.AltModifier);
    return modifiers === 0 ? "foreground" : modifiers === (Qt.ShiftModifier | Qt.ControlModifier) ? "background" : "";
  }

  function keyName(event) {
    // Shift+Tab arrives as Backtab from a keyboard, or as Tab with Shift from some virtual ones.
    if (event.key === Qt.Key_Tab && event.modifiers & Qt.ShiftModifier) return "Backtab";
    // Shift with Return runs what a capital names (rule 6).
    if (event.key === Qt.Key_Return || event.key === Qt.Key_Enter) return event.modifiers & Qt.ShiftModifier ? "Shift+Return" : "Return";
    // Named with Ctrl too, so a surface whose prompt has the keys lists them on C-?.
    if (event.key === Qt.Key_Question) return "?";
    const named = Object.keys(Keys.named).find(name => Keys.named[name].code === event.key);
    if (named) return named;
    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) return String.fromCharCode(event.key);
    if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
      const letter = String.fromCharCode(event.key);
      return event.modifiers & Qt.ShiftModifier ? letter : letter.toLowerCase();
    }
    // Held with Ctrl, a key's text is a control character.
    return event.modifiers & Qt.ControlModifier ? "" : event.text;
  }

  // Pure, so tests/unit reads them without a shell.
  readonly property var named: Keys.named
  readonly property var names: Keys.names
  readonly property var matches: Keys.matches
  readonly property var pick: Keys.pick
  readonly property var label: Keys.label
  readonly property var gutter: Keys.gutter
  readonly property var glob: Keys.glob
  readonly property var assign: Keys.assign

  // Whether an entry runs one command per key (a pair); config lists are list-like, so Array.isArray cannot tell.
  function isPair(entry) {
    return entry?.cmd != null && typeof entry.cmd !== "string";
  }
}
