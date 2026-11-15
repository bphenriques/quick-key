import QtQuick

// What every plugin takes in config.json's `plugins.<name>.settings`; each plugin's Settings.qml adds its own.
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
  // Its compositor key, shown in the header while Super is held.
  property string shortcut
}
