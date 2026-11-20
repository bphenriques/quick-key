pragma Singleton

import QtQuick
import Quickshell

// Asks the menu for a list by name (Lists), filtered in place on a level of its own: what a plugin's panel opens (Ask's C-r), `back` showing it again on Escape.
Singleton {
  // The list last asked for.
  property string list: ""

  signal requested(string list, var back)

  function pick(name, back) {
    list = name;
    requested(name, back ?? null);
  }
}
