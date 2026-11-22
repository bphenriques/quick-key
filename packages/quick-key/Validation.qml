pragma Singleton

import QtQuick
import Quickshell
// By name, not as the folder: so tools see Config as the singleton it is.
import qs
import qs.builtins
import qs.ui

// What is wrong with config.json: the shell logs it as it starts, and check.qml fails on it (docs/src/configuration.md).
Singleton {
  id: root

  // Null until config.json is read; checked once each time it is, not in a binding, as the check makes the plugins' settings to read them.
  readonly property var problems: internal.problems

  function validate() {
    if (Config.written === null) return;
    internal.problems = Config.invalid ? [Config.invalid] : check(Config.written);
    for (const problem of internal.problems) console.warn("config.json:", problem);
  }

  Component.onCompleted: validate()

  Connections {
    target: Config

    function onWrittenChanged() {
      Qt.callLater(root.validate);
    }

    function onInvalidChanged() {
      Qt.callLater(root.validate);
    }
  }

  QtObject {
    id: internal
    property var problems: null
  }

  readonly property var views: ["calendar"]
  // Esc steps back, ? lists the keys no row shows, Tab moves to the input and Shift+Tab back.
  readonly property var reservedKeys: ["Escape", "?", "Tab", "Backtab"]

  // Renamed keys first, so a config from before a rename says what to write instead; then kinds, as the checks after them read the config in the shapes the settings declare.
  function check(json) {
    const moved = renames(json, Config.renamed);
    if (moved.length) return moved;
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

  // Each old key, by its path, that json still sets.
  function renames(json, renamed) {
    return Object.keys(renamed).filter(path => path.split(".").reduce((at, key) => at?.[key], json) !== undefined).map(path => path + " is now " + renamed[path]);
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
    if (typeof input.desc !== "string") found.push("needs an input with a desc");
    if (input.cmd != null && input.plugin != null) found.push("gives its input's text to both input.cmd and input.plugin");
    if (input.plugin != null && !plugins.includes(input.plugin)) found.push("gives its input's text to plugin '" + input.plugin + "', which is not one");
    if (input.cmd == null && input.plugin == null && !plugins.includes(entry.list)) found.push("gives its input's text to nothing: needs input.cmd, input.plugin, or a list that is a plugin");
    if (input.format != null && !String(input.format).includes("{text}")) found.push("sets input.format without {text}, where the text goes");
    return found;
  }

  // Each field an entry takes, and what it asks of the rest: `level`, a level's (submenu, list or view); `needs`, one of these set; `bar`, only in a bar; `names`, a table it names one of, else a plugin; `excludes`, fields it cannot sit beside; `invalid`, what is wrong with its value, else "".
  readonly property var fields: ({
      key: {},
      desc: {},
      cmd: {},
      action: {},
      icon: {},
      width: {},
      submenu: {},
      keepOpen: { needs: ["cmd", "action"] },
      activeWhen: { names: States.builtin },
      columns: { level: true, invalid: columns => Number.isInteger(columns) && columns >= 1 ? "" : "sets columns, which only a level of 1 or more columns takes" },
      list: { names: Lists.builtin },
      pins: { needs: ["list"], invalid: pins => pins.length > 9 ? "has more pins than digits" : "" },
      view: { excludes: ["list"], invalid: view => root.views.includes(view) ? "" : "shows view '" + view + "', which is not built in" },
      status: { names: Statuses.builtin },
      format: { needs: ["status"] },
      header: { level: true },
      shortcut: { bar: true },
      limit: { bar: true, needs: ["list"], invalid: limit => limit >= 1 && limit <= 9 ? "" : "limits its list to " + limit + ", not 1 to 9 digits" },
      input: { level: true }
    })

  // What each set field asks of the rest, as `fields` says.
  function fieldProblems(entry, plugins, inBar) {
    const found = [];
    const level = entry.submenu != null || entry.list != null || entry.view != null;
    for (const [field, rule] of Object.entries(fields)) {
      const value = entry[field];
      if (value == null) continue;
      if (rule.bar && !inBar || rule.level && !level || rule.needs && !rule.needs.some(other => entry[other] != null))
        found.push("can only set " + field + (rule.level ? " on a level with submenu, list or view" : rule.bar ? (rule.needs ? " on a " + rule.needs.join(" or ") : "") + " in a bar" : " with " + rule.needs.join(" or ")));
      if (rule.names && !(value in rule.names) && !plugins.includes(value)) found.push("names " + field + " '" + value + "', neither built in nor a plugin");
      for (const other of rule.excludes ?? []) if (entry[other] != null) found.push("cannot combine " + field + " with " + other);
      if (rule.invalid && rule.invalid(value)) found.push(rule.invalid(value));
    }
    return found;
  }

  // In a bar an entry needs no key, and may only show its status; past what `fields` says, what spans fields.
  function entryProblems(entry, plugins, inBar, list) {
    const found = [];
    const unknown = Object.keys(entry).filter(key => !(key in fields));
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
    found.push(...fieldProblems(entry, plugins, inBar));
    if ((entry.submenu ?? []).some(row => row.icon == null && row.action == null && row.status == null)) found.push("holds an action without an icon");
    if (entry.list != null && (entry.submenu ?? []).some(row => [].concat(row.key ?? []).some(key => /^[0-9]$/.test(key)))) found.push("binds a digit, reserved for its list");
    if (Array.isArray(entry.cmd) && entry.cmd.length !== keys.length) found.push("pairs keys and commands, so needs as many of each");
    if (action?.pair && keys.length !== 2) found.push("runs '" + entry.action + "' per key of a pair, so needs two keys");
    if (entry.input != null) found.push(...inputProblems(entry, plugins));
    return found;
  }
}
