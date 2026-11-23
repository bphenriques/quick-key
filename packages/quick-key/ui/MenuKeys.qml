pragma Singleton

import QtQuick
import Quickshell
import "keys.js" as Keys

// Keys by their xkb names (a, A, Up, space, ...), as menu entries declare them.
Singleton {
  id: root

  // The name of a key event, Ctrl and Alt first when held (Ctrl+Left); Shift only picks the capital letter. "" for a modifier alone.
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
    switch (event.key) {
    case Qt.Key_Up: return "Up";
    case Qt.Key_Down: return "Down";
    case Qt.Key_Left: return "Left";
    case Qt.Key_Right: return "Right";
    case Qt.Key_PageUp: return "Page_Up";
    case Qt.Key_PageDown: return "Page_Down";
    case Qt.Key_Space: return "space";
    // Shift+Tab arrives as Backtab from a keyboard, or as Tab with Shift from some virtual ones.
    case Qt.Key_Tab: return event.modifiers & Qt.ShiftModifier ? "Backtab" : "Tab";
    case Qt.Key_Backtab: return "Backtab";
    case Qt.Key_Return:
    case Qt.Key_Enter: return "Return";
    case Qt.Key_Escape: return "Escape";
    case Qt.Key_Backspace: return "BackSpace";
    }
    if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9) return String.fromCharCode(event.key);
    if (event.key >= Qt.Key_A && event.key <= Qt.Key_Z) {
      const letter = String.fromCharCode(event.key);
      return event.modifiers & Qt.ShiftModifier ? letter : letter.toLowerCase();
    }
    // Held with Ctrl, a key's text is a control character.
    return event.modifiers & Qt.ControlModifier ? "" : event.text;
  }

  // Pure, so tests/unit reads them without a shell.
  readonly property var names: Keys.names
  readonly property var matches: Keys.matches
  readonly property var label: Keys.label
  readonly property var shortName: Keys.shortName
  readonly property var gutter: Keys.gutter
  readonly property var glob: Keys.glob
  readonly property var assign: Keys.assign

  // Whether an entry runs one command per key (a pair); config lists are list-like, so Array.isArray cannot tell.
  function isPair(entry) {
    return entry?.cmd != null && typeof entry.cmd !== "string";
  }
}
