pragma Singleton

import QtQuick
import Quickshell
import qs

// Loads the plugins Config.plugins names, from their source or found by name. One that fails to load is logged and left
// out; the rest of the shell runs on.
Singleton {
  id: root

  function get(name) {
    return internal.loaded[name] ?? null;
  }

  // As the menu opens, so plugins read what has no events.
  function refresh() {
    for (const plugin of Object.values(internal.loaded)) plugin.refresh();
  }

  QtObject {
    id: internal

    property var loaded: ({})

    // source is a path when it has a slash, else the plugin implementing this one, by default its own name. A plugin's
    // file is its name capitalised (niriMinimap: NiriMinimap.qml), in the user's plugins folder or shipped.
    function component(name, spec) {
      const source = spec.source ?? name;
      const file = source.charAt(0).toUpperCase() + source.slice(1) + ".qml";
      const sources = source.includes("/") ? [source] : [Config.configDir + "/plugins/" + file, "plugins/" + file];
      let found = null;
      for (const path of sources) {
        found = Qt.createComponent(path.startsWith("/") ? "file://" + path : Quickshell.shellPath(path));
        if (found.status === Component.Ready) break;
      }
      return found;
    }

    function load(name, spec) {
      const component = internal.component(name, spec);
      if (component.status !== Component.Ready) {
        console.warn("plugin", name, "not loaded:", component.errorString());
        return null;
      }
      const plugin = component.createObject(root, { name: name, settings: spec.settings ?? {} });
      if (!plugin) console.warn("plugin", name, "not created");
      return plugin;
    }

    function reload() {
      for (const plugin of Object.values(loaded)) plugin.destroy();
      const next = {};
      for (const [name, spec] of Object.entries(Config.plugins)) {
        const plugin = load(name, spec);
        if (plugin) next[name] = plugin;
      }
      loaded = next;
    }
  }

  // The config may have loaded before this singleton was created.
  Component.onCompleted: internal.reload()

  Connections {
    target: Config

    function onPluginsChanged() {
      internal.reload();
    }
  }
}
