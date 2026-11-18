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

  // What its source last gave over the look `settings.show` (else the matching static item) gives its `value`; {} without one.
  readonly property var state: compose(source.state)

  // What a menu entry with `status` set to the name shows, and whether one with `activeWhen` set to it is lit; by default, the state.
  property string glyph: state.glyph ?? ""
  property string text: state.text ?? ""
  property string detail: state.detail ?? ""
  property bool active: state.active ?? false
  // The status's tone when it needs one (alert for do-not-disturb); unset, lit by active.
  property string tone: state.tone ?? ""
  // Why it failed, its source's `error` or its own; a level listing it shows it under its keys.
  property string error: state.error ?? ""
  // Why its list is empty, shown in its place (No tasks); by default, its state's own `empty`.
  property string empty: state.empty ?? ""
  // What an entry's `format` reads by name, beside `text` and `detail`.
  property var fields: state.fields ?? ({})
  // Its compositor key, shown beside it while Super is held.
  property string shortcut: settings.shortcut

  // What a menu entry with `list` set to its name shows, each { id, label, icon, glyphs, detail, active, enabled, done, busy, tone }.
  property var items: state.items ?? []

  // What a click on it in a bar, or `<name> activate` over IPC, does.
  function activate() {}

  // What choosing one of its items does, given the item's id.
  function select(id) {}

  // What a level's input does with its text, for an entry whose `input` sets no `cmd`.
  function submit(text) {}

  // Called as the menu opens, and by `<name> refresh` over IPC, to read what has no events.
  function refresh() {
    source.refresh();
  }

  // The line's own fields win over the look; static items light by `value` and dim unless in `enabled`.
  function compose(line) {
    const value = line.value == null ? undefined : String(line.value);
    const fixed = Array.from(settings.items);
    const item = fixed.find(item => item.id === value);
    const look = value === undefined ? {} : settings.show[value] ?? (item ? { glyph: item.icon ?? "", text: item.label ?? item.id } : { text: value });
    const enabled = line.enabled ? Array.from(line.enabled) : null;
    const items = fixed.length ? fixed.map(item => Object.assign({}, item, { active: item.id === value, enabled: !enabled || enabled.includes(item.id) })) : line.items;
    return Object.assign({}, look, line, items ? { items } : {});
  }

  // A command from its settings as a Process takes it, the arguments passed as $1, $2... so none is parsed by the shell.
  function commandLine(shell, ...args) {
    return Commands.line(shell, ...args);
  }

  // Runs a command from its settings and forgets it; nothing when unset.
  function exec(shell, ...args) {
    Commands.run(shell, ...args);
  }

  Component.onCompleted: {
    for (const file of views) {
      const component = Qt.createComponent(folder + file);
      if (!component.createObject(root, { plugin: root })) console.warn("plugin", name + ":", file, "not created:", component.errorString());
    }
  }

  Timer {
    interval: root.settings.every * 1000
    running: root.settings.every > 0 && root.settings.read !== "" && Plugins.menuOpen
    repeat: true
    onTriggered: source.refresh()
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
