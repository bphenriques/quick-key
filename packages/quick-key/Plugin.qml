import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.ui

// The root of every plugin (see docs/src/plugins.md).
Scope {
  id: root

  // Set by the shell: the plugin's name in Config.plugins, and its settings there read through its Settings.qml.
  property string name
  readonly property string title: settings.title || name
  required property PluginSettings settings
  // Set by the shell: the folder its files are in.
  property string folder
  // Its surfaces: files in its folder, each given `plugin` and created with it, so what it draws only reads its state.
  property list<string> views: []

  // What its source last gave over the look `settings.show` (else the matching static item) gives its `value`; {} without one.
  readonly property var state: compose(source.state)

  // What a menu entry with `status` set to the name shows, and whether one with `activeWhen` set to it is lit; by default, the state.
  property string glyph: state.glyph ?? settings.glyph
  property string text: state.text ?? ""
  property string detail: state.detail ?? ""
  property bool active: state.active ?? false
  // Its value's own tone when it needs one (warning on a late count); unset, its phase's, else lit by active.
  property string tone: state.tone ?? ""
  // Its work (Phase): idle, working, blocked on you with its `kind`, done or error; by default its state's, an unknown word idle.
  property string phase: Phase.of(state.phase)
  property string kind: Phase.kinds.includes(state.kind) ? state.kind : ""
  // Why it failed, its source's `error` or its own; a level listing it shows it under its keys.
  property string error: state.error ?? ""
  // Why its list is empty, shown in its place (No tasks); by default, its state's own `empty`.
  property string empty: state.empty ?? ""
  // Glyphs before its detail, in its tone: a state colour alone should not carry (a late task's alarm).
  property var glyphs: state.glyphs ?? []
  // What an entry's `format` reads by name, beside `text` and `detail`.
  property var fields: state.fields ?? ({})
  // A tone per field, kept when a `format` shows it (warning on an old sync).
  property var fieldTones: state.fieldTones ?? ({})
  // Its compositor key, shown beside it while Super is held.
  property string shortcut: settings.shortcut
  // Whether the menu shows an input giving it text: set as a visit starts (InputModel), and cleared by `endVisit` as it ends, a change of the input or the menu closing.
  property bool watched: false
  signal visitEnded

  function endVisit() {
    watched = false;
    visitEnded();
  }
  // The turn of the conversation that text started, as the menu draws it while watched (Exchange): { question, context, text, phase, kind, activity, options, table, steps }, `context` the answer a working turn follows, `steps` what you answered on the way, `phase` as Phase names it: working, done, blocked on a question (`options` a digit picks) or for permission, error (the input gets the text back) or idle (stopped); null before the first.
  property var turn: null
  // Whether it takes no text now, a run under way, working or blocked on you; an input giving it text shows a spinner meanwhile and sends nothing.
  readonly property bool busy: phase === "working" || phase === "blocked"

  // What a menu entry with `list` set to its name shows, each { id, label, icon, glyphs, detail, active, enabled, done, hidden, busy, tone, verb, closes, actions }: `verb` names what choosing it does, `closes` hides the surface first, `actions` ([{ key, desc, icon, closes }]) are its own menu.
  property var items: state.items ?? []
  // Actions by name, as the built-in ones (builtins/Actions.qml), for the entries of a level listing it.
  property var actions: ({})
  // Its own words, what only it says, as Words holds those the surfaces share.
  property var words: ({})

  // What a click on it in a bar, or `<name> activate` over IPC, does.
  function activate() {
    exec(settings.activate);
  }

  // A key path on a surface of its own (`<name> press "2 m"` over IPC), run as typing it would: what a binding runs; false if it has none.
  function press(path) {
    return false;
  }

  // What choosing one of its items does, given the item's id.
  function select(id) {}

  // An action from an item's own menu, given the item's id and the action's key.
  function run(id, key) {}

  // A level's input's text, when it sets no `cmd`: `background` from C-S-RET, `after` to run once done with it; false if not taken, the input keeping it.
  function submit(text, background, after) {
    console.warn(name + ": takes no text, so the input keeps it");
    return false;
  }

  // Whether `recall` shows its past conversations, which C-r in an input giving it text opens.
  property bool recalls: false

  // Its past conversations in the picker (Picker), over what opened it; false without.
  function recall() {
    return false;
  }

  // Its own panel on the conversation an input's text started, for what an answer cannot fit, opened over the menu (Panels), which stepping back shows again; false without a panel.
  function expand() {
    return false;
  }

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

  // Runs a command from its settings with its arguments, then always `then(code, output)`: unset, it fails as sh finding no command would (127).
  function call(shell, args, then) {
    if (!shell) {
      if (then) then(127, "");
      return;
    }
    const process = job.createObject(root, { command: commandLine(shell, ...args), then: then ?? null });
    process.running = true;
  }

  // `running` is set after creation, never declared: a running that turns true before `command` is set starts nothing (see services/CommandReader.qml).
  Component {
    id: job

    CommandProcess {
      id: process
      property var then
      stdout: StdioCollector {
        id: output
      }
      onExited: code => {
        if (process.then) process.then(code, output.text);
        process.destroy();
      }
    }
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

    // One of its actions by name, as an entry naming it runs it: what a compositor binding calls.
    function action(name: string): void {
      const action = root.actions[name];
      if (action?.available([])) action.run(false, [], null);
    }

    function press(path: string): void {
      root.press(path);
    }
  }
}
