import QtQuick

// What every plugin takes in config.json's `plugins.<name>.settings`; each plugin's Settings.qml adds its own.
QtObject {
  // Its one source of state, at most one set (docs/src/plugins.md#sources).
  property string watch
  property string read
  property string file
  // Its compositor key, shown in the header while Super is held.
  property string shortcut
}
