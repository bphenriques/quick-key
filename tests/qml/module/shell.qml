import QtQuick
import Quickshell
import qs
import qs.builtins

// The shell and the module name the same things: $BUILTINS is builtins.nix, $SETTINGS the keys of settings.nix.
ShellRoot {
  id: root

  readonly property var builtins: JSON.parse(Quickshell.env("BUILTINS"))
  readonly property var settings: JSON.parse(Quickshell.env("SETTINGS"))

  function isObject(value) {
    return value != null && typeof value === "object" && "objectName" in value;
  }

  // Dotted paths of the keys under a group, which for an object are its properties: not its name, signals or functions.
  function paths(group, isGroup, prefix) {
    let found = [];
    for (const key of Object.keys(group)) {
      const value = group[key];
      if (key === "objectName" || typeof value === "function") continue;
      found = found.concat(isGroup(value) ? paths(value, isGroup, prefix + key + ".") : [prefix + key]);
    }
    return found;
  }

  // Config's groups: what the module names, and any object of its own but the colours it resolves.
  function read() {
    const groups = {};
    for (const key of Object.keys(Config)) if (key in settings || (isObject(Config[key]) && key !== "colors")) groups[key] = Config[key];
    return paths(groups, isObject, "");
  }

  function same(names, list) {
    return JSON.stringify([...names].sort()) === JSON.stringify([...list].sort());
  }

  Suite {
    cases: [
      {
        name: "the shell defines each built-in name the module accepts, and no other",
        until: () => root.same(Object.keys(Statuses.builtin), root.builtins.statuses) && root.same(Object.keys(Lists.builtin), root.builtins.lists)
          && root.same(Object.keys(States.builtin), root.builtins.states) && root.same(Object.keys(HeaderItems.builtin), root.builtins.headerItems)
          && root.same(Object.keys(Actions.builtin), root.builtins.actions)
          && root.same(Object.keys(Actions.builtin).filter(name => Actions.builtin[name].pair), root.builtins.pairs)
      },
      {
        name: "the shell reads each setting the module declares, and no other",
        until: () => root.same(root.read(), root.paths(root.settings, value => value !== null, ""))
      }
    ]
  }
}
