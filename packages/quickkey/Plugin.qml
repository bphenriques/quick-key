import QtQuick
import Quickshell

// The root of every plugin (see docs/src/plugins.md).
Scope {
  // Set by the shell: the plugin's name in Config.plugins, and its settings there.
  property string name
  property var settings: ({})

  // What a menu entry with `status` set to the name shows, and whether one with `activeWhen` set to it is lit.
  property string glyph
  property string text
  property string detail
  property bool active: false
  // The status's tone when it needs one (alert for do-not-disturb); unset, lit by active.
  property string tone
  // Its compositor key, shown in the header while Super is held; set from its settings by the module that binds it.
  property string shortcut

  // What a menu entry with `list` set to its name shows, each { id, label, icon, detail, active, enabled }.
  property var items: []

  // What a click on its header item does.
  function activate() {}

  // What choosing one of its items does, given the item's id.
  function select(id) {}

  // Called as the menu opens, to read what has no events.
  function refresh() {}

  // A command from its settings as a Process takes it, the arguments passed as $1, $2... so none is parsed by the shell.
  function commandLine(shell, ...args) {
    return ["sh", "-c", shell + args.map((_, i) => ' "$' + (i + 1) + '"').join(""), "sh", ...args];
  }

  // Runs a command from its settings and forgets it; nothing when unset.
  function exec(shell, ...args) {
    if (shell) Quickshell.execDetached(commandLine(shell, ...args));
  }
}
