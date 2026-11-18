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

  readonly property var entryKeys: ["key", "desc", "cmd", "action", "keepOpen", "activeWhen", "width", "submenu", "list", "pins", "view", "status", "icon", "format", "header", "shortcut", "limit"]
  readonly property var views: ["calendar"]
  // Esc closes the menu and Backspace goes back a level.
  readonly property var reservedKeys: ["Escape", "BackSpace"]

  function check(json) {
    const plugins = Object.keys(json.plugins ?? {});
    // The top level's bar as it will be, the starter's slots included.
    const header = { left: json.menu?.header?.left ?? Config.starterHeader.left, center: json.menu?.header?.center ?? Config.starterHeader.center, right: json.menu?.header?.right ?? Config.starterHeader.right };
    return Config.undeclared(json).concat(pluginProblems(json.plugins ?? {}), levelProblems("the top level", json.menu?.entries ?? [], header, plugins));
  }

  function pluginProblems(plugins) {
    const builtin = [Statuses, Lists, States].reduce((names, table) => names.concat(Object.keys(table.builtin)), []);
    const found = [];
    for (const [name, plugin] of Object.entries(plugins)) {
      const at = "plugins." + name;
      if (builtin.includes(name)) found.push(at + " takes a built-in name");
      if (["watch", "read", "file"].filter(source => plugin[source] != null).length > 1) found.push(at + " sets more than one of watch, read and file");
      if (plugin.every != null && plugin.read == null) found.push(at + " sets every without read");
    }
    return found;
  }

  // A level's keys in its body and its bar, then each entry and the level under it.
  function levelProblems(path, entries, header, plugins) {
    const keys = entries.reduce((keys, entry) => keys.concat(entry.key ?? []), []);
    const bar = ["left", "center", "right"].reduce((parts, slot) => parts.concat(Array.from(header?.[slot] ?? [])), []);
    const barEntries = bar.filter(part => typeof part !== "string");
    const barKeys = barEntries.reduce((keys, entry) => keys.concat(entry.key ?? []), []);
    const found = [];
    const wrong = (which, why) => {
      if (which.length) found.push("menu: " + why + " in " + path + ": " + [...new Set(which)].join(", "));
    };
    wrong(keys.filter((key, index) => keys.indexOf(key) !== index), "keys bound twice");
    wrong(keys.filter(key => key !== "+" && !/^((Ctrl|Alt)\+)*[^+]+$/.test(key)), "keys with a modifier other than Ctrl+ or Alt+");
    wrong(keys.filter(key => /^((Ctrl|Alt)\+)+[0-9]$/.test(key)), "keys that reach a listed item's own menu or the bar's list");
    wrong(keys.filter(key => reservedKeys.includes(key)), "keys reserved for the menu");
    wrong(barKeys.filter((key, index) => barKeys.indexOf(key) !== index), "bar keys bound twice");
    wrong(barKeys.filter(key => key !== "+" && key.includes("+")), "bar keys with a modifier, which Ctrl already takes");
    wrong(barKeys.filter(key => /^[0-9]$/.test(key)), "bar keys on a digit, reserved for its lists");
    wrong(barKeys.filter(key => keys.includes("Ctrl+" + key)), "bar keys its body binds with Ctrl too");
    for (const name of bar.filter(part => typeof part === "string"))
      if (!(name in Statuses.builtin) && !plugins.includes(name)) found.push("menu: '" + name + "' in " + path + "'s bar is neither a status nor a plugin");
    for (const [entry, inBar] of entries.map(entry => [entry, false]).concat(barEntries.map(entry => [entry, true]))) {
      found.push(...entryProblems(entry, plugins, inBar).map(problem => "menu: '" + (entry.desc ?? entry.key) + "' in " + path + (inBar ? "'s bar " : " ") + problem));
      if (entry.submenu || entry.header) found.push(...levelProblems(path + " > " + entry.desc, entry.submenu ?? [], entry.header, plugins));
    }
    return found;
  }

  // In a bar an entry needs no key, and may only show its status.
  function entryProblems(entry, plugins, inBar) {
    const found = [];
    const named = (field, table) => {
      if (entry[field] != null && !(entry[field] in table) && !plugins.includes(entry[field])) found.push("names " + field + " '" + entry[field] + "', neither built in nor a plugin");
    };
    const unknown = Object.keys(entry).filter(key => !entryKeys.includes(key));
    const keys = [].concat(entry.key ?? []);
    const action = Actions.builtin[entry.action];
    const level = entry.submenu != null || entry.list != null || entry.view != null;
    const does = [entry.cmd != null, entry.action != null, level].filter(set => set).length;
    if (unknown.length) found.push("sets " + unknown.join(", ") + ", which no entry takes");
    if (typeof entry.desc !== "string" || !inBar && !keys.length) found.push(inBar ? "needs a desc" : "needs a key and a desc");
    if (does > 1 || does === 0 && !(inBar && entry.status != null))
      found.push("needs one of cmd, action, or submenu and/or list or view" + (inBar ? ", or only a status" : ""));
    if (inBar && entry.list == null && entry.status == null && entry.icon == null && entry.action == null) found.push("shows nothing: needs a status, an icon or an action");
    if (entry.action != null && !action) found.push("runs action '" + entry.action + "', which is not built in");
    named("status", Statuses.builtin);
    named("activeWhen", States.builtin);
    named("list", Lists.builtin);
    if (entry.format != null && entry.status == null) found.push("can only set format with status");
    if (entry.shortcut != null && !inBar) found.push("can only set shortcut in a bar, the only place it shows");
    if (entry.header != null && !level) found.push("can only set header with submenu, list or view");
    if (entry.limit != null && !(inBar && entry.list != null)) found.push("can only set limit on a list in a bar");
    if (entry.limit != null && !(entry.limit >= 1 && entry.limit <= 9)) found.push("limits its list to " + entry.limit + ", not 1 to 9 digits");
    if (entry.view != null && !views.includes(entry.view)) found.push("shows view '" + entry.view + "', which is not built in");
    if (entry.view != null && entry.list != null) found.push("cannot combine view with list");
    if (entry.keepOpen != null && entry.cmd == null && entry.action == null) found.push("can only set keepOpen with cmd or action");
    if ((entry.submenu ?? []).some(row => row.icon == null && row.action == null && row.status == null)) found.push("holds an action without an icon");
    if (entry.pins != null && entry.list == null) found.push("can only set pins with list");
    if ((entry.pins ?? []).length > 9) found.push("has more pins than digits");
    if (entry.list != null && (entry.submenu ?? []).some(row => [].concat(row.key ?? []).some(key => /^[0-9]$/.test(key)))) found.push("binds a digit, reserved for its list");
    if (Array.isArray(entry.cmd) && entry.cmd.length !== keys.length) found.push("pairs keys and commands, so needs as many of each");
    if (action?.pair && keys.length !== 2) found.push("runs '" + entry.action + "' per key of a pair, so needs two keys");
    return found;
  }
}
