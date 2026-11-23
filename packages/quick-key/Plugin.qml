import QtQuick
import Quickshell
import Quickshell.Io
import qs.services
import qs.ui

// The root of every plugin (see docs/src/plugins.md).
Scope {
  id: root

  // Set by the shell, as is `folder`.
  property string name
  readonly property string title: settings.title || name
  required property PluginSettings settings
  property string folder
  property list<string> views: []

  // The source's last line with `show` (else the matching static item) applied; {} without one.
  readonly property var state: compose(source.state)

  property string glyph: state.glyph ?? settings.glyph
  property string text: state.text ?? ""
  property string detail: state.detail ?? ""
  property bool active: state.active ?? false
  // Unset, its phase's, else lit by active.
  property string tone: state.tone ?? ""
  property string phase: Phase.of(state.phase)
  property string kind: Phase.kinds.includes(state.kind) ? state.kind : ""
  property string error: state.error ?? ""
  property string empty: state.empty ?? ""
  property var glyphs: state.glyphs ?? []
  property var fields: state.fields ?? ({})
  property var fieldTones: state.fieldTones ?? ({})
  property string shortcut: settings.shortcut
  // From startVisit (InputModel) to endVisit.
  readonly property bool watched: internal.watched
  signal visitEnded

  function startVisit() {
    internal.watched = true;
  }

  function endVisit() {
    internal.watched = false;
    visitEnded();
  }
  // As the menu draws it (Exchange), its fields in docs/src/plugins.md; null before the first.
  property var turn: null
  readonly property bool busy: phase === "working" || phase === "blocked"

  property var items: state.items ?? []
  property var actions: ({})
  property var words: ({})

  function activate() {
    exec(settings.activate);
  }

  function press(path) {
    return false;
  }

  function select(id) {}

  function run(id, key) {}

  function submit(text, background, after) {
    console.warn(name + ": takes no text, so the input keeps it");
    return false;
  }

  property bool recalls: false

  function recall() {
    return false;
  }

  function expand() {
    return false;
  }

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

  // Arguments as $1, $2... so the shell parses none.
  function commandLine(shell, ...args) {
    return Commands.line(shell, ...args);
  }

  function exec(shell, ...args) {
    Commands.run(shell, ...args);
  }

  // Unset, it fails as sh finding no command would (127).
  function call(shell, args, then) {
    if (!shell) {
      if (then) then(127, "");
      return;
    }
    job.createObject(root, { then: then ?? null }).exec(commandLine(shell, ...args));
  }

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

    // As an entry naming it runs it: what a compositor binding calls.
    function action(name: string): void {
      const action = root.actions[name];
      if (action?.available([])) action.run(false, [], null);
    }

    function press(path: string): void {
      root.press(path);
    }
  }

  QtObject {
    id: internal
    property bool watched: false
  }
}
