pragma Singleton

import QtQuick
import Quickshell
import qs.builtins

// What is wrong with config.json: the shell logs it as it starts, and check.qml fails on it (docs/src/configuration.md).
Singleton {
  id: root

  // Null until config.json is read.
  readonly property var problems: Config.written === null ? null : Config.invalid ? [Config.invalid] : check(Config.written)
  onProblemsChanged: {
    for (const problem of problems ?? []) console.warn("config.json:", problem);
  }

  readonly property var entryKeys: ["key", "desc", "cmd", "action", "keepOpen", "activeWhen", "width", "submenu", "list", "pins", "view", "status", "icon"]
  readonly property var views: ["calendar"]
  // Esc closes the menu and Backspace goes back a level.
  readonly property var reservedKeys: ["Escape", "BackSpace"]

  function check(json) {
    const plugins = Object.keys(json.plugins ?? {});
    return Config.undeclared(json).concat(pluginProblems(json.plugins ?? {}), headerProblems(json.menu?.header ?? {}, plugins),
      levelProblems("the top level", json.menu?.entries ?? [], plugins));
  }

  function pluginProblems(plugins) {
    const builtin = [Statuses, Lists, States, HeaderItems].reduce((names, table) => names.concat(Object.keys(table.builtin)), []);
    const found = [];
    for (const [name, plugin] of Object.entries(plugins)) {
      const at = "plugins." + name;
      if (builtin.includes(name)) found.push(at + " takes a built-in name");
      if (["watch", "read", "file"].filter(source => plugin[source] != null).length > 1) found.push(at + " sets more than one of watch, read and file");
      if (plugin.every != null && plugin.read == null) found.push(at + " sets every without read");
    }
    return found;
  }

  function headerProblems(header, plugins) {
    const found = [];
    for (const slot of Object.keys(header))
      for (const name of header[slot] ?? [])
        if (!(name in HeaderItems.builtin) && !plugins.includes(name)) found.push("menu.header." + slot + ": '" + name + "' is neither built in nor a plugin");
    return found;
  }

  // A level's keys, then each entry and the level under it.
  function levelProblems(path, entries, plugins) {
    const keys = entries.reduce((keys, entry) => keys.concat(entry.key ?? []), []);
    const found = [];
    const wrong = (which, why) => {
      if (which.length) found.push("menu: " + why + " in " + path + ": " + [...new Set(which)].join(", "));
    };
    wrong(keys.filter((key, index) => keys.indexOf(key) !== index), "keys bound twice");
    wrong(keys.filter(key => key !== "+" && !/^((Ctrl|Alt)\+)*[^+]+$/.test(key)), "keys with a modifier other than Ctrl+ or Alt+");
    wrong(keys.filter(key => /^(Alt\+)?Ctrl\+(Alt\+)?[0-9]$/.test(key)), "keys that open a listed item's own menu");
    wrong(keys.filter(key => reservedKeys.includes(key)), "keys reserved for the menu");
    for (const entry of entries) {
      found.push(...entryProblems(entry, plugins).map(problem => "menu: '" + (entry.desc ?? entry.key) + "' in " + path + " " + problem));
      if (entry.submenu) found.push(...levelProblems(path + " > " + entry.desc, entry.submenu, plugins));
    }
    return found;
  }

  function entryProblems(entry, plugins) {
    const found = [];
    const named = (field, table) => {
      if (entry[field] != null && !(entry[field] in table) && !plugins.includes(entry[field])) found.push("names " + field + " '" + entry[field] + "', neither built in nor a plugin");
    };
    const unknown = Object.keys(entry).filter(key => !entryKeys.includes(key));
    const keys = [].concat(entry.key ?? []);
    const action = Actions.builtin[entry.action];
    if (unknown.length) found.push("sets " + unknown.join(", ") + ", which no entry takes");
    if (!keys.length || typeof entry.desc !== "string") found.push("needs a key and a desc");
    if ([entry.cmd != null, entry.action != null, entry.submenu != null || entry.list != null || entry.view != null].filter(set => set).length !== 1)
      found.push("needs one of cmd, action, or submenu and/or list or view");
    if (entry.action != null && !action) found.push("runs action '" + entry.action + "', which is not built in");
    named("status", Statuses.builtin);
    named("activeWhen", States.builtin);
    named("list", Lists.builtin);
    if (entry.view != null && !views.includes(entry.view)) found.push("shows view '" + entry.view + "', which is not built in");
    if (entry.view != null && entry.list != null) found.push("cannot combine view with list");
    if (entry.keepOpen != null && entry.cmd == null && entry.action == null) found.push("can only set keepOpen with cmd or action");
    if ((entry.submenu ?? []).some(row => row.icon == null && row.action == null)) found.push("holds an action without an icon");
    if (entry.pins != null && entry.list == null) found.push("can only set pins with list");
    if ((entry.pins ?? []).length > 9) found.push("has more pins than digits");
    if (entry.list != null && (entry.submenu ?? []).some(row => [].concat(row.key ?? []).some(key => /^[0-9]$/.test(key)))) found.push("binds a digit, reserved for its list");
    if (Array.isArray(entry.cmd) && entry.cmd.length !== keys.length) found.push("pairs keys and commands, so needs as many of each");
    if (action?.pair && keys.length !== 2) found.push("runs '" + entry.action + "' per key of a pair, so needs two keys");
    return found;
  }
}
