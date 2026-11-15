import QtQuick
import Quickshell
import Quickshell.Io
import qs.services

// The root of every plugin (see docs/src/plugins.md).
Scope {
  id: root

  // Set by the shell: the plugin's name in Config.plugins, and its settings there read through its Settings.qml.
  property string name
  required property PluginSettings settings
  // Set by the shell: the folder its files are in.
  property string folder
  // Its surfaces: files in its folder, each given `plugin` and created with it, so what it draws only reads its state.
  property list<string> views: []

  // The state its source (settings.watch, read or file) last gave, each field optional; {} without one.
  readonly property var state: source.state

  // What a menu entry with `status` set to the name shows, and whether one with `activeWhen` set to it is lit.
  property string glyph
  property string text
  property string detail
  property bool active: false
  // The status's tone when it needs one (alert for do-not-disturb); unset, lit by active.
  property string tone
  // Its compositor key, shown in the header while Super is held.
  property string shortcut: settings.shortcut

  // What a menu entry with `list` set to its name shows, each { id, label, icon, detail, active, enabled }.
  property var items: []

  // What a click on its header item, or `<name> activate` over IPC, does.
  function activate() {}

  // What choosing one of its items does, given the item's id.
  function select(id) {}

  // Called as the menu opens, and by `<name> refresh` over IPC, to read what has no events.
  function refresh() {
    source.refresh();
  }

  // A command from its settings as a Process takes it, the arguments passed as $1, $2... so none is parsed by the shell.
  function commandLine(shell, ...args) {
    return ["sh", "-c", shell + args.map((_, i) => ' "$' + (i + 1) + '"').join(""), "sh", ...args];
  }

  // Runs a command from its settings and forgets it; nothing when unset.
  function exec(shell, ...args) {
    if (shell) Quickshell.execDetached(commandLine(shell, ...args));
  }

  Component.onCompleted: {
    if ([settings.watch, settings.read, settings.file].filter(value => value).length > 1) console.warn("plugin", name, "sets more than one of watch, read and file; set one");
    for (const file of views) {
      const component = Qt.createComponent(folder + file);
      if (!component.createObject(root, { plugin: root })) console.warn("plugin", name + ":", file, "not created:", component.errorString());
    }
  }

  CommandState {
    id: source
    watch: root.settings.watch
    read: root.settings.read
    file: root.settings.file
  }

  IpcHandler {
    target: root.name

    function activate(): void {
      root.activate();
    }

    function refresh(): void {
      root.refresh();
    }
  }
}
