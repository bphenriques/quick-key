import QtQuick
import Quickshell
import qs
import qs.services
import qs.widgets
import qs.widgets.menu

ShellRoot {
  // Singletons are created on first use: Config must load before any surface needs it, Tray must host before apps register, Power must have UPower's answer before the menu first opens, Calendar reminds with the menu closed, and plugins load.
  Component.onCompleted: {
    Config.theme;
    Tray.items;
    Power.present;
    Calendar.enabled;
    Validation.problems;
    Plugins.get;
  }

  Menu {}

  Osd {}

  KeepAwakeInhibitor {}

  // What you chose while it runs (Kept), carried over the reload a config change makes; as JSON, as an object would stay with the engine the reload replaces.
  PersistentProperties {
    id: kept
    reloadableId: "kept"
    property string json: "{}"
    onLoaded: Kept.restore(JSON.parse(json))
  }

  Connections {
    target: Kept

    function onValuesChanged() {
      kept.json = JSON.stringify(Kept.values);
    }
  }
}
