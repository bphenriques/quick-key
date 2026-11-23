import QtQuick

// What every plugin takes in config.json's `plugins.<name>`, beside its `type`; each plugin's Settings.qml adds its own.
QtObject {
  // Its one source of state, at most one set: a command printing a line per change, one run as the menu opens, or a file read on every change, relative to $XDG_RUNTIME_DIR (docs/src/plugins.md#sources).
  property string watch
  property string read
  property string file
  // Seconds between runs of `read` while the menu is open; 0 runs it only as the menu opens.
  property int every: 0
  // The look of each value the source gives, by value: any state line field (glyph, text, detail, active, tone, phase, a plugin's own such as stage), the line's own winning; a value without one shows as text.
  property var show: ({})
  // Its items when they never change, each { id, label, icon, detail }; the source's `value` names the one in use.
  property var items: []
  // Its compositor key (Mod+N), only a label: shown while Super is held; the binding is the compositor's.
  property string shortcut
  // Its name in tips, prompts and notifications; unset, its name under `plugins`.
  property string title
  // Its glyph when its state names none.
  property string glyph
  // What a click on it in a bar, or `<name> activate` over IPC, runs.
  property string activate

  // What else is wrong with these settings, each named after plugins.<name> by Validation; bounds are data, a readonly `ranges` ({ name: [least, most] }) and `choices` ({ name: [values] }) of its own, which Validation checks and the reference lists.
  function problems() {
    return [];
  }
}
