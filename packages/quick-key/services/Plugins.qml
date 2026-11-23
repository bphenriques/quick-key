pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.ui

// Loads the plugins Config.plugins names; one that fails to load is logged and left out.
Singleton {
  id: root

  // Whether a keyboard surface (the menu, a plugin's panel) is open, as a plugin's `every` reads while one is.
  readonly property bool menuOpen: Panels.top !== null

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

    function component(name, spec) {
      let found = null;
      for (const url of Config.pluginUrls(name, spec)) {
        found = Qt.createComponent(url);
        if (found.status === Component.Ready) break;
      }
      return found;
    }

    // The plugin's Settings.qml, beside it, set from its part of config.json but `type`; a key it does not declare is logged and left out.
    function settings(name, component, spec) {
      const file = Qt.createComponent(component.url.toString().replace(/[^/]*$/, "Settings.qml"));
      const object = file.createObject(root);
      if (!object) {
        console.warn("plugin", name, "not loaded:", file.errorString());
        return null;
      }
      const given = Config.pluginSettings(object, spec);
      if (given.unknown.length) console.warn("plugin", name + ": ignoring unknown settings:", given.unknown.join(", "));
      if (given.mistyped.length) console.warn("plugin", name + ": ignoring", given.mistyped.join("; "));
      for (const [key, value] of Object.entries(given.values)) object[key] = value;
      return object;
    }

    function load(name, spec) {
      const component = internal.component(name, spec);
      if (component.status !== Component.Ready) {
        console.warn("plugin", name, "not loaded:", component.errorString());
        return null;
      }
      const settings = internal.settings(name, component, spec);
      if (!settings) return null;
      const plugin = component.createObject(root, { name: name, settings: settings, folder: component.url.toString().replace(/[^/]*$/, "") });
      if (!plugin) {
        console.warn("plugin", name, "not created");
        settings.destroy();
      }
      return plugin;
    }

    function reload() {
      for (const plugin of Object.values(loaded)) {
        plugin.settings.destroy();
        plugin.destroy();
      }
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
