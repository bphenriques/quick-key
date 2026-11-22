pragma Singleton

import QtQuick
import Quickshell
import qs.builtins
import qs.ui

// What is wrong with config.json: the shell logs it as it starts, and check.qml fails on it (docs/src/configuration.md).
Singleton {
  id: root

  // Null until config.json is read.
  readonly property var problems: Config.written === null ? null : Config.invalid ? [Config.invalid] : check(Config.written)
  // Logged as the verdict changes: the check runs again as what it reads settles, mostly to the same one.
  onProblemsChanged: {
    const verdict = JSON.stringify(problems ?? []);
    if (verdict === internal.logged) return;
    internal.logged = verdict;
    for (const problem of problems ?? []) console.warn("config.json:", problem);
  }

  QtObject {
    id: internal
    property string logged: "[]"
  }

  readonly property var entryKeys: ["key", "desc", "cmd", "action", "keepOpen", "activeWhen", "width", "columns", "submenu", "list", "pins", "view", "status", "icon", "format", "header", "shortcut", "limit", "input"]
  readonly property var views: ["calendar"]
  // Esc steps back, ? lists the keys no row shows, Tab moves to the input and Shift+Tab back.
  readonly property var reservedKeys: ["Escape", "?", "Tab", "Backtab"]

  // Kinds first: the checks after them read the config in the shapes the settings declare.
  function check(json) {
    const kinds = Config.undeclared(json);
    if (kinds.length) return kinds;
    const plugins = Object.keys(json.plugins ?? {});
    // The top level's bar as it will be, the starter's slots included.
    const header = { left: json.menu?.header?.left ?? Config.starterHeader.left, center: json.menu?.header?.center ?? Config.starterHeader.center, right: json.menu?.header?.right ?? Config.starterHeader.right };
    // The top level's input is checked as an entry's would be.
    const input = json.menu?.input == null ? [] : inputProblems({ submenu: [], input: json.menu.input }, plugins).map(problem => "menu.input " + problem);
    return pluginProblems(json.plugins ?? {}).concat(glyphProblems(json.glyphs ?? {}),
      // A pop-up draws a status or a plugin; anything else would sit armed on nothing.
      (json.popups?.show ?? []).filter(name => !(name in Statuses.builtin) && !plugins.includes(name)).map(name => "popups.show: '" + name + "' is neither a status nor a plugin"),
      levelProblems("the top level", json.menu?.entries ?? [], header, plugins, null), input);
  }

  // A glyph by its name in Glyphs, of the same kind: a glyph, a list of them, or a map (audioDevices); objectName is what Glyphs inherits as a QObject.
  function glyphProblems(glyphs) {
    return Object.keys(glyphs).map(name => !(name in Glyphs) || name === "objectName" || typeof Glyphs[name] === "function" ? "glyphs." + name + " is not a glyph"
      : typeof glyphs[name] !== typeof Glyphs[name] ? "glyphs." + name + " takes a " + (typeof Glyphs[name] === "string" ? "glyph" : Array.isArray(Glyphs[name]) ? "list of glyphs" : "map of glyphs") : "").filter(problem => problem);
  }

  function pluginProblems(plugins) {
    const builtin = [Statuses, Lists, States].reduce((names, table) => names.concat(Object.keys(table.builtin)), []);
    const found = [];
    for (const [name, plugin] of Object.entries(plugins)) {
      const at = "plugins." + name;
      if (Config.kind(plugin) !== "map") {
        found.push(at + " takes a map of settings");
        continue;
      }
      if (builtin.includes(name)) found.push(at + " takes a built-in name");
      if (["watch", "read", "file"].filter(source => plugin[source] != null).length > 1) found.push(at + " sets more than one of watch, read and file");
      if (plugin.every != null && plugin.read == null) found.push(at + " sets every without read");
      // Every plugin's look and static items, as Plugin.compose reads them: a look by value, an item matched by its id as the source's value, a string.
      if (Config.kind(plugin.show) === "map")
        found.push(...Object.keys(plugin.show).filter(value => Config.kind(plugin.show[value]) !== "map").map(value => at + ".show." + value + " takes a map: glyph, text, detail, active, tone"));
      if (Config.kind(plugin.items) === "list")
        found.push(...Array.from(plugin.items).map((item, i) => Config.kind(item) === "map" && typeof item.id === "string" ? "" : at + ".items[" + i + "] takes a map with a string id").filter(problem => problem));
      let settings = null;
      for (const url of Config.pluginUrls(name, plugin)) {
        const component = Qt.createComponent(url.replace(/[^/]*$/, "Settings.qml"));
        if (component.status === Component.Ready) {
          settings = component;
          break;
        }
      }
      // None: a user's plugin may be absent where the build runs; its loading logs it.
      if (settings) {
        // Kinds read from defaults, then problems() from an object made with the values given: one written after being read would loop this binding.
        const defaults = settings.createObject(null);
        // Ready is not enough: settings that fail to instantiate name themselves, they do not hang the check.
        if (!defaults) {
          found.push(at + " Settings.qml does not instantiate");
          continue;
        }
        const given = Object.assign({}, plugin);
        delete given.type;
        for (const key of Object.keys(given)) {
          if (Config.settable(defaults, key)) given[key] = Config.over(defaults[key], given[key]);
          else {
            found.push(at + "." + key + " is not a setting");
            delete given[key];
          }
        }
        found.push(...Config.undeclared(given, defaults, at + "."));
        // Its own checks on what it declares, so every problem shows at once, not one build at a time.
        const declared = {};
        for (const [key, value] of Object.entries(given)) if (defaults[key] === null || Config.kind(value) === Config.kind(defaults[key])) declared[key] = value;
        defaults.destroy();
        const object = settings.createObject(null, declared);
        found.push(...object.problems().map(problem => at + " " + problem));
        object.destroy();
      }
    }
    return found;
  }

  // A level's shape, its keys in its body and its bar, then each entry and the level under it.
  function levelProblems(path, given, header, plugins, list) {
    if (Config.kind(given) !== "list") return ["menu: " + path + " takes a list of entries"];
    const entries = Array.from(given).filter(entry => Config.kind(entry) === "map");
    const bar = ["left", "center", "right"].reduce((parts, slot) => parts.concat(Array.from(header?.[slot] ?? [])), []);
    const barEntries = bar.filter(part => Config.kind(part) === "map");
    const keys = entries.reduce((keys, entry) => keys.concat(entry.key ?? []), []);
    const barKeys = barEntries.reduce((keys, entry) => keys.concat(entry.key ?? []), []);
    const found = [];
    if (entries.length < given.length || bar.some(part => Config.kind(part) !== "map" && typeof part !== "string")) found.push("menu: " + path + " holds something that is not an entry");
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
      found.push(...entryProblems(entry, plugins, inBar, list).map(problem => "menu: '" + (entry.desc ?? entry.key) + "' in " + path + (inBar ? "'s bar " : " ") + problem));
      if (entry.submenu || entry.header) found.push(...levelProblems(path + " > " + entry.desc, entry.submenu ?? [], entry.header, plugins, entry.list));
    }
    return found;
  }

  // An input takes a letter its level leaves free, and gives its text to its cmd, its plugin or else to a plugin the level lists.
  function inputProblems(entry, plugins) {
    const input = entry.input;
    const found = [];
    const unknown = Object.keys(input).filter(key => !["desc", "cmd", "plugin", "format", "after"].includes(key));
    if (unknown.length) found.push("sets input." + unknown.join(", input.") + ", which no input takes");
    if (entry.submenu == null && entry.list == null && entry.view == null) found.push("can only set input on a level with submenu, list or view");
    if (typeof input.desc !== "string") found.push("needs an input with a desc");
    if (input.cmd != null && input.plugin != null) found.push("gives its input's text to both input.cmd and input.plugin");
    if (input.plugin != null && !plugins.includes(input.plugin)) found.push("gives its input's text to plugin '" + input.plugin + "', which is not one");
    if (input.cmd == null && input.plugin == null && !plugins.includes(entry.list)) found.push("gives its input's text to nothing: needs input.cmd, input.plugin, or a list that is a plugin");
    if (input.format != null && !String(input.format).includes("{text}")) found.push("sets input.format without {text}, where the text goes");
    return found;
  }

  // In a bar an entry needs no key, and may only show its status.
  function entryProblems(entry, plugins, inBar, list) {
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
    // A plugin's actions are its own, known only once it runs: on a level listing one, any name may be one.
    if (entry.action != null && !action && !plugins.includes(list)) found.push("runs action '" + entry.action + "', which is not built in nor its level's plugin's");
    named("status", Statuses.builtin);
    named("activeWhen", States.builtin);
    named("list", Lists.builtin);
    if (entry.format != null && entry.status == null) found.push("can only set format with status");
    if (entry.shortcut != null && !inBar) found.push("can only set shortcut in a bar, the only place it shows");
    if (entry.header != null && !level) found.push("can only set header with submenu, list or view");
    if (entry.limit != null && !(inBar && entry.list != null)) found.push("can only set limit on a list in a bar");
    if (entry.limit != null && !(entry.limit >= 1 && entry.limit <= 9)) found.push("limits its list to " + entry.limit + ", not 1 to 9 digits");
    if (entry.columns != null && !(Number.isInteger(entry.columns) && entry.columns >= 1 && (entry.submenu || entry.list || entry.view))) found.push("sets columns, which only a level of 1 or more columns takes");
    if (entry.view != null && !views.includes(entry.view)) found.push("shows view '" + entry.view + "', which is not built in");
    if (entry.view != null && entry.list != null) found.push("cannot combine view with list");
    if (entry.keepOpen != null && entry.cmd == null && entry.action == null) found.push("can only set keepOpen with cmd or action");
    if ((entry.submenu ?? []).some(row => row.icon == null && row.action == null && row.status == null)) found.push("holds an action without an icon");
    if (entry.pins != null && entry.list == null) found.push("can only set pins with list");
    if ((entry.pins ?? []).length > 9) found.push("has more pins than digits");
    if (entry.list != null && (entry.submenu ?? []).some(row => [].concat(row.key ?? []).some(key => /^[0-9]$/.test(key)))) found.push("binds a digit, reserved for its list");
    if (Array.isArray(entry.cmd) && entry.cmd.length !== keys.length) found.push("pairs keys and commands, so needs as many of each");
    if (action?.pair && keys.length !== 2) found.push("runs '" + entry.action + "' per key of a pair, so needs two keys");
    if (entry.input != null) found.push(...inputProblems(entry, plugins));
    return found;
  }
}
