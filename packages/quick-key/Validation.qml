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
    // A check that throws still ends with a verdict: check.qml waits for one, and a build for check.qml.
    try {
      internal.problems = Config.invalid ? [Config.invalid] : check(Config.written);
    } catch (error) {
      internal.problems = ["the check failed on a value of an unexpected kind: " + error];
    }
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

  // Esc steps back, ? lists the keys no row shows, Tab moves to the input and Shift+Tab back.
  readonly property var reservedKeys: ["Escape", "?", "Tab", "Backtab"]

  // Renamed keys first, so a config from before a rename says what to write instead; then kinds, as the checks after them read the config in the shapes the settings declare.
  function check(json) {
    const moved = renames(json, Config.renamed);
    if (moved.length) return moved;
    const kinds = Config.undeclared(json);
    if (kinds.length) return kinds;
    const values = numberProblems(json).concat(colourProblems(json.theme ?? {}), choiceProblems(json));
    const plugins = Object.keys(json.plugins ?? {});
    // The top level's bar as it will be, the starter's slots included.
    const header = Object.assign({}, json.menu?.header);
    for (const slot of ["left", "center", "right"]) header[slot] = header[slot] ?? Config.starterHeader[slot];
    // The top level's input is checked as an entry's would be.
    const input = json.menu?.input == null ? [] : inputProblems({ submenu: [], input: json.menu.input }, plugins).map(problem => "menu.input " + problem);
    return values.concat(pluginProblems(json.plugins ?? {}), glyphProblems(json.glyphs ?? {}), patternProblems(json.music?.titleMatch ?? ""),
      // A pop-up draws a status or a plugin; anything else would sit armed on nothing.
      (json.popups?.show ?? []).filter(name => !(name in Statuses.builtin) && !plugins.includes(name)).map(name => "popups.show: '" + name + "' is neither a status nor a plugin"),
      levelProblems("the top level", json.menu?.entries ?? [], header, plugins, null), input);
  }

  // What a number takes beyond being one: 0 or more, an opacity at most 1, and these their own [least, most]: sizes past which no screen lays the shell out, so a typo fails here rather than on screen.
  readonly property var ranges: ({
      "theme.fontSize": [6, 32],
      "theme.lineHeight": [0.1, 4],
      "theme.iconSize": [4, 128],
      "menu.margin": [0, 400],
      "popups.margin": [0, 400],
      "theme.padding": [0, 50],
      "theme.spacing": [0, 50],
      "theme.itemPaddingX": [0, 50],
      "theme.itemPaddingY": [0, 50],
      "theme.listSpacing": [0, 50],
      "theme.borderWidth": [0, 20],
      "theme.radius": [0, 100],
      "theme.itemRadius": [0, 100],
      "theme.dimOpacity": [0.2, 1],
      "theme.disabledOpacity": [0.2, 1],
      "theme.animationDuration": [0, 2000],
      "theme.meterLength": [8, 1000],
      "theme.meterThickness": [1, 50],
      "popups.timeout": [100, 60000],
      "theme.edgeMargin": [0, 400],
      "theme.osdIconSize": [4, 256],
      "theme.osdLength": [8, 4000],
      "menu.width": [200],
      "menu.columns": [1, 9],
      "audio.step": [1],
      "audio.max": [1, 150],
      "brightness.step": [1],
      "clock.firstDayOfWeek": [-1, 6]
    })

  // A number's [least, most] by its path, most undefined or Infinity for none.
  function range(path) {
    return ranges[path] ?? [0, path.endsWith("Opacity") ? 1 : Infinity];
  }

  // Numbers that are counts or point sizes, which a fraction would be cut from.
  readonly property var wholes: ["theme.fontSize", "menu.columns"]

  function numberProblems(json) {
    const found = [];
    for (const [group, kinds] of Object.entries(Config.declaredKinds)) {
      if (typeof kinds !== "object") continue;
      for (const [name, kind] of Object.entries(kinds)) {
        const value = json[group]?.[name];
        if (kind !== "number" || typeof value !== "number") continue;
        const [least, most] = range(group + "." + name);
        if (wholes.includes(group + "." + name) && !Number.isInteger(value)) found.push(group + "." + name + " is " + value + ", not a whole number");
        const bounds = most === undefined || most === Infinity ? least + " or more" : least + " to " + most;
        if (value < least || value > (most ?? Infinity)) found.push(group + "." + name + " is " + value + ", not " + bounds);
      }
    }
    const [low, critical] = [json.battery?.low ?? Config.battery.low, json.battery?.critical ?? Config.battery.critical];
    if (critical >= low) found.push("battery.critical is " + critical + ", not below battery.low (" + low + ")");
    return found;
  }

  // What a text setting with a few meanings takes, by its path.
  readonly property var choices: ({
      "theme.appIcons": ["colour", "grey", "tint"],
      "menu.inputSide": ["body", "bar"],
      "popups.position": ["right", "left", "top", "bottom"]
    })

  function choiceProblems(json) {
    return Object.keys(choices).filter(path => at(json, path) !== undefined && !choices[path].includes(at(json, path)))
      .map(path => path + " is '" + at(json, path) + "', not one of " + choices[path].join(", "));
  }

  // A colour as Qt reads it: #rgb, #rrggbb, or #aarrggbb with its alpha first; any other text would draw black. Its names are Config.colors'.
  function colourProblems(theme) {
    const colour = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;
    return Object.keys(Config.colors).filter(name => typeof theme[name] === "string" && theme[name] !== "" && !colour.test(theme[name]))
      .map(name => "theme." + name + ": '" + theme[name] + "' is no colour (#rrggbb, or #aarrggbb)");
  }

  // Each old key, by its path, that json still sets.
  function renames(json, renamed) {
    return Object.keys(renamed).filter(path => at(json, path) !== undefined).map(path => path + " is now " + renamed[path]);
  }

  function at(json, path) {
    return path.split(".").reduce((value, key) => value?.[key], json);
  }

  function patternProblems(titleMatch) {
    try {
      new RegExp(titleMatch);
      return [];
    } catch (error) {
      return ["music.titleMatch: '" + titleMatch + "' is no regular expression: " + error.message];
    }
  }

  // A glyph by its name in Glyphs, of the same kind: a glyph, a list of them, or a map (audioDevices); objectName is what Glyphs inherits as a QObject.
  function glyphProblems(glyphs) {
    const kind = name => typeof Glyphs[name] === "string" ? "glyph" : Array.isArray(Glyphs[name]) ? "list of glyphs" : "map of glyphs";
    return Object.keys(glyphs).map(name => !(name in Glyphs) || name === "objectName" || typeof Glyphs[name] === "function" ? "glyphs." + name + " is not a glyph"
      : Config.kind(glyphs[name]) !== Config.kind(Glyphs[name]) ? "glyphs." + name + " takes a " + kind(name) : "").filter(problem => problem);
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
      if (plugin.type != null && typeof plugin.type !== "string") {
        found.push(at + ".type takes a plugin's name or path");
        continue;
      }
      if (builtin.includes(name)) found.push(at + " takes a built-in name");
      if (["watch", "read", "file"].filter(source => plugin[source] != null).length > 1) found.push(at + " sets more than one of watch, read and file");
      if (plugin.every != null && plugin.read == null) found.push(at + " sets every without read");
      // Every plugin's look and static items, as Plugin.compose reads them: a look by value, an item matched by its id as the source's value, a string.
      if (Config.kind(plugin.show) === "map")
        found.push(...Object.keys(plugin.show).filter(value => Config.kind(plugin.show[value]) !== "map").map(value => at + ".show." + value + " takes a map: glyph, text, detail, active, tone"));
      const items = Config.kind(plugin.items) === "list" ? Array.from(plugin.items) : [];
      items.forEach((item, i) => {
        if (Config.kind(item) !== "map" || typeof item.id !== "string") found.push(at + ".items[" + i + "] takes a map with a string id");
      });
      let settings = null;
      for (const url of Config.pluginUrls(name, plugin)) {
        const component = Qt.createComponent(url.replace(/[^/]*$/, "Settings.qml"));
        if (component.status === Component.Ready) {
          settings = component;
          break;
        }
      }
      // The module copies a user's plugins beside the config it checks, so one not found is one the shell will not find either.
      if (!settings) {
        found.push(at + " names type '" + (plugin.type ?? name) + "', which is neither shipped nor in " + Config.configDir + "/plugins");
        continue;
      }
      // Kinds read from defaults, then problems() from an object made with the values given: one written after being read would loop this binding.
      const defaults = settings.createObject(null);
      // Ready is not enough: settings that fail to instantiate name themselves, they do not hang the check.
      if (!defaults) {
        found.push(at + " Settings.qml does not instantiate");
        continue;
      }
      const given = Config.pluginSettings(defaults, plugin);
      found.push(...given.unknown.map(key => at + "." + key + " is not a setting"));
      found.push(...given.mistyped.map(problem => at + "." + problem));
      defaults.destroy();
      // Its own checks on what it declares, so every problem shows at once, not one build at a time.
      const object = settings.createObject(null, given.values);
      found.push(...object.problems().map(problem => at + " " + problem));
      object.destroy();
    }
    return found;
  }

  // A level's shape, its keys in its body and its bar, then each entry and the level under it.
  function levelProblems(path, given, header, plugins, list) {
    if (Config.kind(given) !== "list") return ["menu: " + path + " takes a list of entries"];
    const entries = Array.from(given).filter(entry => Config.kind(entry) === "map");
    const slots = ["left", "center", "right"];
    const bar = slots.reduce((parts, slot) => parts.concat(Config.kind(header?.[slot]) === "list" ? Array.from(header[slot]) : []), []);
    const barEntries = bar.filter(part => Config.kind(part) === "map");
    // Key names only: one of another kind is its entry's own problem.
    const keys = entries.reduce((keys, entry) => keys.concat(entry.key ?? []), []).filter(key => typeof key === "string");
    const barKeys = barEntries.reduce((keys, entry) => keys.concat(entry.key ?? []), []).filter(key => typeof key === "string");
    const found = [];
    for (const slot of Object.keys(header ?? {})) {
      if (!slots.includes(slot)) found.push("menu: " + path + "'s bar sets " + slot + ", none of left, center, right");
      else if (header[slot] != null && Config.kind(header[slot]) !== "list") found.push("menu: " + path + "'s bar sets " + slot + " to no list");
    }
    if (entries.length < given.length || bar.some(part => Config.kind(part) !== "map" && typeof part !== "string")) found.push("menu: " + path + " holds something that is not an entry");
    const wrong = (which, why) => {
      if (which.length) found.push("menu: " + why + " in " + path + ": " + [...new Set(which)].join(", "));
    };
    wrong(keys.filter((key, index) => keys.indexOf(key) !== index), "keys bound twice");
    // As MenuKeys names a key event: a named key, a letter or a digit, after Ctrl+ or Alt+; one symbol, after Alt+ at most, as Ctrl gives a symbol no name.
    const sendable = key => /^((Ctrl|Alt)\+)*(Up|Down|Left|Right|space|Tab|Backtab|Return|Escape|BackSpace|[A-Za-z0-9])$/.test(key) || /^(Alt\+)?[^\sA-Za-z0-9]$/.test(key);
    wrong(keys.filter(key => !sendable(key)), "keys no keyboard sends (an arrow, space, Return, BackSpace, a letter or a digit, after Ctrl+ or Alt+, or one symbol)");
    wrong(keys.filter(key => /^((Ctrl|Alt)\+)+[0-9]$/.test(key)), "keys that reach a listed item's own menu or the bar's list");
    wrong(keys.filter(key => reservedKeys.includes(key)), "keys reserved for the menu");
    wrong(barKeys.filter((key, index) => barKeys.indexOf(key) !== index), "bar keys bound twice");
    wrong(barKeys.filter(key => key !== "+" && key.includes("+")), "bar keys with a modifier, which Ctrl already takes");
    wrong(barKeys.filter(key => /^[^\sA-Za-z0-9]$/.test(key)), "bar keys on a symbol, which Ctrl gives no name");
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

  // Each field an entry takes, its comment what it does (the docs' reference), and what it asks: `kind`, the kinds of value it takes; `level`, a level's (submenu, list or view); `needs`, one of these set; `bar`, only in a bar; `names`, a table it names one of, else a plugin; `excludes`, fields it cannot sit beside; `invalid`, what is wrong with its value, else "".
  readonly property var fields: Object.assign(Object.create(null), {
      // Its key, or a pair of keys sharing a row (["Down", "Up"]); a bar entry needs none.
      key: { kind: ["string", "list"] },
      // Its label, which never changes.
      desc: { kind: "string" },
      // A shell command, which closes the menu; a list pairs one with each key.
      cmd: { kind: ["string", "list"] },
      // A built-in action, or one of the plugin its level lists.
      action: { kind: "string" },
      // Its glyph; an action brings its own.
      icon: { kind: "string" },
      // Its level's width in pixels, over menu.width.
      width: { kind: "number", invalid: width => width >= 1 ? "" : "sets width to " + width + ", no size in pixels" },
      // Its level's entries.
      submenu: { kind: "list" },
      // Keeps the menu open once its cmd runs.
      keepOpen: { kind: "boolean", needs: ["cmd", "action"] },
      // Lights it while the state it names is on.
      activeWhen: { kind: "string", names: States.builtin },
      // The columns its level lays its actions out in, over menu.columns.
      columns: { kind: "number", level: true, invalid: columns => Number.isInteger(columns) && columns >= 1 && columns <= 9 ? "" : "sets columns, which only a level of 1 to 9 columns takes" },
      // Its level lists these items on digits.
      list: { kind: "string", names: Lists.builtin },
      // The ids of items kept on their digits, in order, dim while absent.
      pins: { kind: "list", needs: ["list"], invalid: pins => pins.length > 9 ? "has more pins than digits" : "" },
      // Its level shows this view in place of a menu.
      view: { kind: "string", excludes: ["list"], invalid: view => view in Views.builtin ? "" : "shows view '" + view + "', which is not built in" },
      // Live state on the right of its row.
      status: { kind: "string", names: Statuses.builtin },
      // Its status's fields to show ("{song}"), what follows a | kept whole on the right.
      format: { kind: "string", needs: ["status"] },
      // Its level's bar: left, center and right, as menu.header.
      header: { kind: "map", level: true },
      // Its compositor key (Mod+N), only a label: shown while Super is held.
      shortcut: { kind: "string", bar: true },
      // The most items of its list a bar shows; past it, +N.
      limit: { kind: "number", bar: true, needs: ["list"], invalid: limit => limit >= 1 && limit <= 9 ? "" : "limits its list to " + limit + ", not 1 to 9 digits" },
      // A line of text over its level, given to a command or a plugin: { desc, cmd or plugin, format, after }.
      input: { kind: "map", level: true }
    })

  // What each set field asks of the rest, as `fields` says.
  function fieldProblems(entry, plugins, inBar) {
    const found = [];
    const level = entry.submenu != null || entry.list != null || entry.view != null;
    for (const [field, rule] of Object.entries(fields)) {
      const value = entry[field];
      if (value == null) continue;
      const kinds = [].concat(rule.kind);
      if (!kinds.includes(Config.kind(value))) {
        found.push("sets " + field + " to a " + Config.kind(value) + ", not a " + kinds.join(" or a "));
        continue;
      }
      if (rule.bar && !inBar || rule.level && !level || rule.needs && !rule.needs.some(other => entry[other] != null)) {
        const needs = rule.needs ? rule.needs.join(" or ") : "";
        const where = rule.level ? " on a level with submenu, list or view" : rule.bar ? (needs ? " on a " + needs : "") + " in a bar" : " with " + needs;
        found.push("can only set " + field + where);
      }
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
    const rows = Config.kind(entry.submenu) === "list" ? Array.from(entry.submenu).filter(row => Config.kind(row) === "map") : [];
    if (Config.kind(entry.key) === "list" && !keys.every(key => typeof key === "string")) found.push("sets key to no key names");
    const action = Actions.builtin[entry.action];
    const level = entry.submenu != null || entry.list != null || entry.view != null;
    const does = [entry.cmd != null, entry.action != null, level].filter(set => set).length;
    if (unknown.length) found.push("sets " + unknown.join(", ") + ", which no entry takes");
    const status = Statuses.builtin[entry.status];
    const named = status && typeof entry.format === "string" ? (entry.format.match(/\{\w+\}/g) ?? []).filter(name => !status.names.includes(name.slice(1, -1))) : [];
    if (named.length) found.push("formats " + named.join(", ") + ", which " + entry.status + " has not (" + (status.names.map(name => "{" + name + "}").join(", ") || "none") + ")");
    if (typeof entry.desc !== "string" || !inBar && !keys.length) found.push(inBar ? "needs a desc" : "needs a key and a desc");
    if (does > 1 || does === 0 && !(inBar && entry.status != null))
      found.push("needs one of cmd, action, or submenu and/or list or view" + (inBar ? ", or only a status" : ""));
    if (inBar && entry.list == null && entry.status == null && entry.icon == null && entry.action == null) found.push("shows nothing: needs a status, an icon or an action");
    // A plugin's actions are its own, known only once it runs: on a level listing one, any name may be one.
    if (entry.action != null && !action && !plugins.includes(list)) found.push("runs action '" + entry.action + "', which is not built in nor its level's plugin's");
    found.push(...fieldProblems(entry, plugins, inBar));
    if (rows.some(row => row.icon == null && row.action == null && row.status == null)) found.push("holds an action without an icon");
    if (entry.list != null && rows.some(row => [].concat(row.key ?? []).some(key => /^[0-9]$/.test(key)))) found.push("binds a digit, reserved for its list");
    if (Array.isArray(entry.cmd) && entry.cmd.length !== keys.length) found.push("pairs keys and commands, so needs as many of each");
    if (action?.pair && keys.length !== 2) found.push("runs '" + entry.action + "' per key of a pair, so needs two keys");
    if (entry.input != null) found.push(...inputProblems(entry, plugins));
    return found;
  }
}
