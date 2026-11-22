import QtQuick

// What every plugin takes in config.json's `plugins.<name>`, beside its `type`; each plugin's Settings.qml adds its own.
QtObject {
  // Its one source of state, at most one set (docs/src/plugins.md#sources).
  property string watch
  property string read
  property string file
  // Seconds between reads of `read` while the menu is open; 0 reads only as it opens.
  property int every: 0
  // The look of each value the source gives, by value: { glyph, text, detail, active, tone }.
  property var show: ({})
  // Its items when they never change, each { id, label, icon, detail }; the source's `value` names the one in use.
  property var items: []
  // Its compositor key, only a label: shown beside it while Super is held, bound in the compositor.
  property string shortcut
  // Its name, in tips, prompts and notifications; unset, the plugin's.
  property string title
  // Its glyph when its state names none.
  property string glyph
  // What a click on it in a bar, or `<name> activate` over IPC, runs.
  property string activate

  // What else is wrong with these settings, each named after plugins.<name> by Validation.
  function problems() {
    return [];
  }
}
