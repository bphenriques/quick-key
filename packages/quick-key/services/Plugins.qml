pragma Singleton

import QtQuick
import Quickshell
import qs

// Loads the plugins Config.plugins names; one that fails to load is logged and left out.
Singleton {
  id: root

  // Set by the menu while it is open, when plugins with `every` read again.
  property bool menuOpen: false
  // Set by the menu: the plugin whose input it shows, and that input, so a change of either ends a visit; "" while none shows.
  property string watching: ""

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

    // A type with a slash is a plugin file's path, else a plugin's name: its folder, in the user's plugins then the shipped ones.
    function component(name, spec) {
      const type = spec.type ?? name;
      const file = type + "/" + type.charAt(0).toUpperCase() + type.slice(1) + ".qml";
      const paths = type.includes("/") ? [type] : [Config.configDir + "/plugins/" + file, "plugins/" + file];
      let found = null;
      for (const path of paths) {
        found = Qt.createComponent(path.startsWith("/") ? "file://" + path : Quickshell.shellPath(path));
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
      const keys = Object.keys(spec).filter(key => key !== "type");
      const unknown = keys.filter(key => !(key in object));
      if (unknown.length) console.warn("plugin", name + ": ignoring unknown settings:", unknown.join(", "));
      for (const key of keys) if (key in object) object[key] = spec[key];
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
