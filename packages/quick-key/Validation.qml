pragma Singleton

import QtQuick
import Quickshell
// By name, not as the folder: so tools see Config as the singleton it is.
import qs
import qs.builtins
import qs.ui
import "widgets/menu/keymap.js" as Keymap

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

    // Config sets invalid just before written, so this sees both.
    function onWrittenChanged() {
      Qt.callLater(root.validate);
    }
  }

  QtObject {
    id: internal
    property var problems: null
  }

  // Esc steps back, ? lists the keys no row shows, Tab moves to the input and Shift+Tab back.
  readonly property var reservedKeys: ["Escape", "?", "Tab", "Backtab"]

  // Renamed keys, saying what to write instead, beside what else is wrong without them; kinds before the rest, as the checks after them read the config in the shapes the settings declare.
  function check(json) {
    const moved = renames(json, Config.renamed);
    if (moved.length) json = without(json, Object.keys(Config.renamed));
    const kinds = Config.undeclared(json);
    if (kinds.length) return moved.concat(kinds);
    const values = moved.concat(settingProblems(json), colourProblems(json.theme ?? {}), operatorProblems(json));
    const plugins = Object.keys(json.plugins ?? {});
    // The top level's bar as it will be, the starter's slots included.
    const bar = Object.assign({}, json.menu?.bar);
    for (const slot of ["left", "center", "right"]) bar[slot] = bar[slot] ?? Config.starterBar[slot];
    // An input shows only on a layout's input island: what hides it, else "".
    const noInput = json.menu?.layout == null || Array.from(json.menu.layout).includes("input") ? "" : "menu.layout";
    // The top level's input is checked as an entry's would be.
    const input = json.menu?.input == null ? [] : inputProblems({ submenu: [], input: json.menu.input }, plugins).map(problem => "menu.input " + problem)
      .concat(noInput ? ["menu.input is set, but menu.layout shows no input"] : []);
    return values.concat(pluginProblems(json.plugins ?? {}), glyphProblems(json.glyphs ?? {}), patternProblems(json.music?.titleMatch ?? ""),
      // A pop-up draws a status or a plugin; anything else would sit armed on nothing.
      (json.popups?.show ?? []).filter(name => !(name in Statuses.builtin) && !plugins.includes(name)).map(name => "popups.show: '" + name + "' is neither a status nor a plugin"),
      levelProblems("the top level", json.menu?.entries ?? [], bar, plugins, null, noInput, pinsOf(json.menu?.layout).map(pin => pin.level)), input,
      json.menu?.layout == null ? [] : layoutProblems("menu.layout", json.menu.layout, json.menu.entries ?? Config.starterEntries, bar, "top-level entry"),
      json.menu?.height == null ? [] : Config.kind(json.menu.height) === "number" ? valueProblems("menu.height is ", json.menu.height, fields.height) : ["menu.height takes a number"]);
  }

  // The islands a layout names, each at most once.
  readonly property var islands: ["input", "body", "bar"]

  // What a layout pins: each { level = "t"; }.
  function pinsOf(layout) {
    return Config.kind(layout) === "list" ? Array.from(layout).filter(island => Config.kind(island) === "map") : [];
  }

  // A layout draws its levels in its one body and pins each entry with a level of the level declaring it at most once; `said` names it, `where` what it pins.
  function layoutProblems(said, layout, given, bar, where) {
    layout = Array.from(layout);
    const count = name => layout.filter(island => island === name).length;
    const found = layout.filter(island => !islands.includes(island) && Config.kind(island) !== "map")
      .map(island => typeof island === "string" ? said + " names '" + island + "', none of " + islands.join(", ") : said + " holds a " + Config.kind(island) + ", not an island's name or a pinned level");
    if (!count("body")) found.push(said + " shows no body, where levels draw");
    found.push(...islands.filter(name => count(name) > 1).map(name => said + " shows " + name + " more than once"));
    const entries = Array.from(given).filter(entry => Config.kind(entry) === "map");
    const barred = ["left", "center", "right"].reduce((all, slot) => all.concat(Config.kind(bar[slot]) === "list" ? Array.from(bar[slot]) : []), []);
    const keys = pinsOf(layout).map(pin => pin.level);
    for (const [i, pin] of pinsOf(layout).entries()) {
      const entry = entries.find(entry => entry.key === pin.level);
      const pins = said + " pins '" + pin.level + "'";
      const unknown = Object.keys(pin).filter(field => field !== "level");
      if (unknown.length) found.push(said + " holds a pinned level setting " + unknown.join(", ") + ", which it does not take" + (typeof pin.level === "string" ? ": set it on the entry on '" + pin.level + "'" : ""));
      if (typeof pin.level !== "string") found.push(said + " holds a pinned level without a key: { level = \"t\"; } pins the " + where + " on t");
      else if (/\s/.test(pin.level)) found.push(pins + ", a key path: a pinned level takes the key of one " + where);
      else if (!entry) found.push(pins + (barred.some(part => part?.key === pin.level) ? ", a bar entry: a pinned level takes one " + where : ", which no " + where + " binds"));
      else if (entry.submenu == null && entry.list == null && entry.view == null) found.push(pins + ", which opens no level");
      else if (keys.indexOf(pin.level) < i) found.push(pins + " more than once");
    }
    return found;
  }

  // What a number takes beyond being one: 0 or more, an opacity at most 1, and these their own [least, most]: sizes past which no screen lays the shell out, so a typo fails here rather than on screen.
  readonly property var ranges: ({
      "theme.fontSize": [6, 32],
      "theme.lineHeight": [0.1, 4],
      "theme.iconSize": [4, 128],
      "theme.padding": [0, 50],
      "theme.spacing": [0, 50],
      "theme.borderWidth": [0, 20],
      "theme.radius": [0, 100],
      "theme.itemRadius": [0, 100],
      "theme.dimOpacity": [0.2, 1],
      "theme.disabledOpacity": [0.2, 1],
      "theme.animationDuration": [0, 2000],
      "popups.timeout": [100, 60000],
      "theme.edgeMargin": [0, 400],
      "menu.width": [200],
      "menu.columns": [1, 9],
      "audio.step": [1],
      "audio.max": [1, 150],
      "brightness.step": [1],
      "clock.firstDayOfWeek": [-1, 6]
    })

  // Numbers that are counts or point sizes, which a fraction would be cut from.
  readonly property var wholes: ["theme.fontSize", "menu.columns"]

  // What a text setting with a few meanings takes, by its path.
  readonly property var choices: ({
      "theme.appIcons": ["colour", "grey", "tint"]
    })

  // What the setting at path takes beyond its kind, as valueProblems reads a rule.
  function rule(path, kind) {
    return kind === "number" ? { range: ranges[path] ?? [0, path.endsWith("Opacity") ? 1 : Infinity], whole: wholes.includes(path) } : { choices: choices[path] };
  }

  // A [least, most] in words, most undefined or Infinity for none, as the check and the reference say it.
  function bounds([least, most]) {
    return most === undefined || most === Infinity ? least + " or more" : least + " to " + most;
  }

  // What is wrong with a value by its rule ({ range, whole, choices }: a setting's, a plugin's or a field's), each after `subject`.
  function valueProblems(subject, value, rule) {
    const said = subject + (typeof value === "string" ? "'" + value + "'" : value) + ", not ";
    return [rule.whole && !Number.isInteger(value) ? "a whole number" : "", rule.range && (value < rule.range[0] || value > (rule.range[1] ?? Infinity)) ? bounds(rule.range) : "",
      rule.choices && !rule.choices.includes(value) ? "one of " + rule.choices.join(", ") : ""].filter(why => why).map(why => said + why);
  }

  function settingProblems(json) {
    const found = [];
    for (const [group, kinds] of Object.entries(Config.declaredKinds))
      if (typeof kinds === "object") for (const [name, kind] of Object.entries(kinds))
        if (Config.kind(json[group]?.[name]) === kind) found.push(...valueProblems(group + "." + name + " is ", json[group][name], rule(group + "." + name, kind)));
    const [low, critical] = [json.battery?.low ?? Config.battery.low, json.battery?.critical ?? Config.battery.critical];
    if (critical >= low) found.push("battery.critical is " + critical + ", not below battery.low (" + low + ")");
    return found;
  }

  readonly property string colourForms: "#rgb, #rrggbb or #aarrggbb"

  // A colour as Qt reads it, its alpha first; any other text would draw black. Its names are Config.colors'.
  function colourProblems(theme) {
    const colour = /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/;
    return Object.keys(Config.colors).filter(name => typeof theme[name] === "string" && theme[name] !== "" && !colour.test(theme[name]))
      .map(name => "theme." + name + ": '" + theme[name] + "' is no colour (" + colourForms + ")");
  }

  // A command takes its arguments after its text ("$1" "$2"), so one ending in a control operator would run the first as a program; an escaped \; is none.
  function endsInOperator(path, text) {
    const end = typeof text === "string" ? text.match(/[^\\\s]\s*([;&|]+)\s*$/) : null;
    return end ? [path + " ends in '" + end[1] + "', so an argument given it would run as a command"] : [];
  }

  // Every text setting, the plugins' too, as any may be a command.
  function operatorProblems(json) {
    const found = [];
    for (const [group, kinds] of Object.entries(Config.declaredKinds))
      if (typeof kinds === "object") for (const name of Object.keys(kinds)) found.push(...endsInOperator(group + "." + name, json[group]?.[name]));
    for (const [name, plugin] of Object.entries(json.plugins ?? {}))
      if (Config.kind(plugin) === "map") for (const key of Object.keys(plugin)) found.push(...endsInOperator("plugins." + name + "." + key, plugin[key]));
    return found;
  }

  // Each old key, by its path, that json still sets.
  function renames(json, renamed) {
    return Object.keys(renamed).filter(path => at(json, path) !== undefined).map(path => path + " is " + renamed[path]);
  }

  // A copy of json without the keys at `paths`.
  function without(json, paths) {
    const copy = JSON.parse(JSON.stringify(json));
    for (const path of paths) {
      const parent = at(copy, path.slice(0, path.lastIndexOf(".")));
      if (Config.kind(parent) === "map") delete parent[path.slice(path.lastIndexOf(".") + 1)];
    }
    return copy;
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
    // With the names the shell takes itself: Menu's IPC target, the inputs' kept drafts.
    const builtin = [Statuses, Lists, States].reduce((names, table) => names.concat(Object.keys(table.builtin)), ["menu", "drafts"]);
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
        found.push(at + " names type '" + (plugin.type ?? name) + "', which is neither shipped nor in " + Config.configDir + "/plugins"
          + (plugin.type == null ? "; for a command plugin, set type = \"command\"" : ""));
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
      if (Config.kind(plugin.legend) === "list" && legendProblem(plugin.legend)) found.push(at + "." + legendProblem(plugin.legend));
      defaults.destroy();
      // Its own checks on what it declares, so every problem shows at once, not one build at a time.
      const object = settings.createObject(null, given.values);
      for (const [key, range] of Object.entries(object.ranges ?? {})) found.push(...valueProblems(at + "." + key + " is ", object[key], { range }));
      for (const [key, choices] of Object.entries(object.choices ?? {})) found.push(...valueProblems(at + "." + key + " is ", object[key], { choices }));
      found.push(...object.problems().map(problem => at + " " + problem));
      object.destroy();
    }
    return found;
  }

  // A level's shape, its keys in its body and its bar, then each entry and the level under it; `noInput`, what layout hides its input, else ""; `pinned`, the keys of its entries the layout pins; `view`, what it shows.
  function levelProblems(path, given, bar, plugins, list, noInput, pinned = [], view = "") {
    if (Config.kind(given) !== "list") return ["menu: " + path + " takes a list of entries"];
    const entries = Array.from(given).filter(entry => Config.kind(entry) === "map");
    const slots = ["left", "center", "right"];
    const parts = slots.reduce((found, slot) => found.concat(Config.kind(bar?.[slot]) === "list" ? Array.from(bar[slot]) : []), []);
    const barEntries = parts.filter(part => Config.kind(part) === "map");
    // Key names only: one of another kind is its entry's own problem.
    const keys = entries.reduce((keys, entry) => keys.concat(entry.key ?? []), []).filter(key => typeof key === "string");
    const barKeys = barEntries.reduce((keys, entry) => keys.concat(entry.key ?? []), []).filter(key => typeof key === "string");
    const found = [];
    for (const slot of Object.keys(bar ?? {})) {
      if (!slots.includes(slot)) found.push("menu: " + path + "'s bar sets " + slot + ", none of left, center, right");
      else if (bar[slot] != null && Config.kind(bar[slot]) !== "list") found.push((path === "the top level" ? "menu.bar." : "menu: " + path + "'s bar.") + slot + " takes a list");
    }
    if (entries.length < given.length || parts.some(part => Config.kind(part) !== "map" && typeof part !== "string")) found.push("menu: " + path + " holds something that is not an entry");
    const wrong = (which, why) => {
      if (which.length) found.push("menu: " + why + " in " + path + ": " + [...new Set(which)].join(", "));
    };
    // Two things on one key on one screen (keymap.js), by who holds it; one pinned level's own are its level's to name.
    const clashes = new Map();
    const owner = binding => (binding.what === "view" ? binding.label : "'" + (binding.label ?? binding.key) + "'")
      + (binding.island === "bar" ? " on the bar" : binding.island === "body" ? "" : " on pinned " + binding.island);
    for (const { key, held } of Keymap.overlaps(Keymap.ofLevel({ entries, pinned, bar: barEntries, view }, Views.builtin))) {
      const owners = held.map(owner).join(" and ");
      if (!held.every(binding => binding.island === held[0].island && !["body", "bar"].includes(binding.island))) clashes.set(owners, (clashes.get(owners) ?? []).concat(key));
    }
    for (const [owners, keys] of clashes) found.push("menu: " + path + " puts two things on " + keys.join(", ") + ": " + owners);
    // As MenuKeys names a key event: a named key, a letter or a digit, after Ctrl+ or Alt+; one symbol, after Alt+ at most, as Ctrl gives a symbol no name.
    const named = Object.keys(MenuKeys.named).filter(name => MenuKeys.named[name].bindable !== false);
    const sendable = key => new RegExp("^((Ctrl|Alt)\\+)*(" + named.join("|") + "|[A-Za-z0-9])$").test(key) || /^(Alt\+)?[^\sA-Za-z0-9]$/.test(key);
    wrong(keys.filter(key => !sendable(key)), "keys no keyboard sends (an arrow, space, Return, BackSpace, a letter or a digit, after Ctrl+ or Alt+, or one symbol)");
    wrong(keys.filter(key => /^((Ctrl|Alt)\+)+[0-9]$/.test(key)), "keys that reach a listed item's own menu or the bar's list");
    wrong(keys.filter(key => reservedKeys.includes(key)), "keys reserved for the menu");
    wrong(barKeys.filter(key => key !== "+" && key.includes("+")), "bar keys with a modifier, which Ctrl already takes");
    wrong(barKeys.filter(key => /^[^\sA-Za-z0-9]$/.test(key)), "bar keys on a symbol, which Ctrl gives no name");
    wrong(barKeys.filter(key => /^[0-9]$/.test(key)), "bar keys on a digit, reserved for its lists");
    for (const name of parts.filter(part => typeof part === "string"))
      if (!(name in Statuses.builtin) && !plugins.includes(name)) found.push("menu: '" + name + "' in " + path + "'s bar is neither a status nor a plugin");
    for (const [entry, inBar] of entries.map(entry => [entry, false]).concat(barEntries.map(entry => [entry, true]))) {
      // Its level shows in its own layout, else in the one it opens from.
      const hides = Config.kind(entry.layout) !== "list" ? noInput : Array.from(entry.layout).includes("input") ? "" : "its level's layout";
      found.push(...entryProblems(entry, plugins, inBar, list, hides, !inBar && pinned.includes(entry.key)).map(problem => "menu: '" + (entry.desc ?? entry.key) + "' in " + path + (inBar ? "'s bar " : " ") + problem));
      // A submenu of another kind is its entry's own problem (fields).
      if (entry.submenu || entry.bar) found.push(...levelProblems(path + " > " + entry.desc, Config.kind(entry.submenu) === "list" ? entry.submenu : [], entry.bar, plugins, entry.list, hides, pinsOf(entry.layout).map(pin => pin.level), entry.view));
    }
    return found;
  }

  // An input takes a letter its level leaves free, and gives its text to its cmd, its plugin or else to a plugin the level lists.
  function inputProblems(entry, plugins) {
    const input = entry.input;
    const found = [];
    const unknown = Object.keys(input).filter(key => !["desc", "cmd", "plugin", "context", "format", "after"].includes(key));
    if (unknown.length) found.push("sets input." + unknown.join(", input.") + ", which no input takes");
    if (typeof input.desc !== "string") found.push("needs an input with a desc");
    if (input.cmd != null && input.plugin != null) found.push("gives its input's text to both input.cmd and input.plugin");
    if (input.plugin != null && !plugins.includes(input.plugin)) found.push("gives its input's text to plugin '" + input.plugin + "', which is not one");
    if (input.cmd == null && input.plugin == null && !plugins.includes(entry.list)) found.push("gives its input's text to nothing: needs input.cmd, input.plugin, or a list that is a plugin");
    if (input.format != null) found.push("sets input.format, now input.context: what the agent is told beside each message, the text sent as typed");
    if (input.context != null && input.cmd != null) found.push("sets input.context, which only a plugin is told: input.cmd gets the text alone");
    found.push(...endsInOperator("input.cmd", input.cmd));
    return found;
  }

  // A `legend` naming what is no key as `?` names one (Ctrl+Up, Page_Down, Ctrl+ for a hold), else "": what a level lists there follows its state, so no more is known here.
  function legendProblem(names) {
    const key = new RegExp("^(?=.)((Ctrl|Alt|Shift|Super)\\+)*(" + Object.keys(MenuKeys.named).join("|") + "|\\S)?$");
    const wrong = Array.from(names).filter(name => typeof name !== "string" || !key.test(name));
    return wrong.length ? "legend names no key as ? names them (Ctrl+Up, Page_Down): " + wrong.join(", ") : "";
  }

  // Each field an entry takes, its comment what it does (the docs' reference), and what it asks: `kind`, the kinds of value it takes; `level`, a level's (submenu, list or view); `needs`, one of these set; `bar`, only in a bar (`pinned`: or pinned); `names`, a table it names one of, else a plugin; `excludes`, fields it cannot sit beside; `range`, `whole` and `choices`, as a setting's rule; `invalid`, what else is wrong with its value, else "".
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
      width: { kind: "number", range: [1] },
      // The rows its level's body holds at least, over menu.height: unset, it fits what it shows.
      height: { kind: "number", needs: ["submenu", "list"], excludes: ["view", "limit"], range: [1], whole: true },
      // Its level's entries.
      submenu: { kind: "list" },
      // Keeps the menu open once its cmd runs, or its action at the end of a key path that opened the menu.
      keepOpen: { kind: "boolean", needs: ["cmd", "action"] },
      // Lights it while the state it names is on.
      activeWhen: { kind: "string", names: States.builtin },
      // The columns its level lays its actions out in, over menu.columns.
      columns: { kind: "number", level: true, range: ranges["menu.columns"], whole: true },
      // Its level lists these items on digits.
      list: { kind: "string", names: Lists.builtin },
      // Items kept on their digits, in order, dim while absent: each { match, label, icon }, a glob on the item's id, what it is called, and an optional glyph.
      pins: { kind: "list", needs: ["list"], invalid: pins => pins.length > 9 ? "has more pins than digits"
        : Array.from(pins).every(pin => Config.kind(pin) === "map" && typeof pin.match === "string" && typeof pin.label === "string") ? "" : "takes each pin as { match, label }, two strings" },
      // Its level shows this view in place of a menu.
      view: { kind: "string", excludes: ["list"], choices: Object.keys(Views.builtin) },
      // Live state on the right of its row.
      status: { kind: "string", names: Statuses.builtin },
      // Its status's fields to show ("{song}"), what follows a | kept whole on the right.
      format: { kind: "string", needs: ["status"] },
      // Its level's bar: left, center and right, as menu.bar.
      bar: { kind: "map", level: true },
      // Its compositor key (Mod+N), only a label: shown while Super is held.
      shortcut: { kind: "string", bar: true },
      // The most items of its list a bar or its pinned level shows; past it, the rest on 0.
      limit: { kind: "number", bar: true, pinned: true, needs: ["list"], range: [1, 9] },
      // A line of text over its level, given to a command or a plugin: { desc, cmd or plugin, context, after }.
      input: { kind: "map", level: true },
      // Its level's islands, as menu.layout, until ESC; unset, it opens in the current layout's body.
      layout: { kind: "list", level: true },
      // Keys of its level's `?` list to show in its bar too, after the bar's own: ["Ctrl+Up"].
      legend: { kind: "list", level: true, invalid: names => legendProblem(names) }
    })

  // Fields renamed, as Config.renamed names settings: an entry still setting one is told what to write instead.
  readonly property var renamedFields: Object.assign(Object.create(null), {
      header: "now bar"
    })

  // What each set field asks of the rest, as `fields` says.
  function fieldProblems(entry, plugins, inBar, pinned) {
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
      if (rule.bar && !inBar && !(rule.pinned && pinned) || rule.level && !level || rule.needs && !rule.needs.some(other => entry[other] != null)) {
        const needs = rule.needs ? rule.needs.join(" or ") : "";
        const where = rule.level ? " on a level with submenu, list or view" : rule.bar ? (needs ? " on a " + needs : "") + " in a bar" + (rule.pinned ? " or pinned" : "") : " with " + needs;
        found.push("can only set " + field + where);
      }
      if (rule.names && !(value in rule.names) && !plugins.includes(value)) found.push("names " + field + " '" + value + "', neither built in nor a plugin");
      for (const other of rule.excludes ?? []) if (entry[other] != null) found.push("cannot combine " + field + " with " + other);
      found.push(...valueProblems("sets " + field + " to ", value, rule));
      if (rule.invalid && rule.invalid(value)) found.push(rule.invalid(value));
    }
    return found;
  }

  // In a bar an entry needs no key, and may only show its status; past what `fields` says, what spans fields.
  function entryProblems(entry, plugins, inBar, list, noInput, pinned) {
    const found = [];
    const unknown = Object.keys(entry).filter(key => !(key in fields) && !(key in renamedFields));
    const keys = [].concat(entry.key ?? []);
    const rows = Config.kind(entry.submenu) === "list" ? Array.from(entry.submenu).filter(row => Config.kind(row) === "map") : [];
    if (Config.kind(entry.key) === "list" && !keys.every(key => typeof key === "string")) found.push("sets key to no key names");
    const action = Actions.builtin[entry.action];
    const level = entry.submenu != null || entry.list != null || entry.view != null;
    const does = [entry.cmd != null, entry.action != null, level].filter(set => set).length;
    if (unknown.length) found.push("sets " + unknown.join(", ") + ", which no entry takes");
    found.push(...Object.keys(entry).filter(key => key in renamedFields).map(key => "sets " + key + ", " + renamedFields[key]));
    const status = Statuses.builtin[entry.status];
    const named = status && typeof entry.format === "string" ? (entry.format.match(/\{\w+\}/g) ?? []).filter(name => !status.names.includes(name.slice(1, -1))) : [];
    if (named.length) found.push("formats " + named.join(", ") + ", which " + entry.status + " has not (" + (status.names.map(name => "{" + name + "}").join(", ") || "none") + ")");
    if (typeof entry.desc !== "string") found.push("needs a desc");
    if (!inBar && !keys.length) found.push("needs a key");
    // A plugin's actions are its own, known only once it runs: on a level listing one, any name may be one.
    if (entry.action != null && !action && !plugins.includes(list)) found.push("runs action '" + entry.action + "', which is neither built in nor its level's plugin's");
    found.push(...fieldProblems(entry, plugins, inBar, pinned));
    // Its island draws its level alone: no row for a status, no bar.
    if (pinned) found.push(...["bar", "layout", "status", "format"].filter(field => entry[field] != null).map(field => "is pinned, so its " + field + " shows nowhere"));
    else if (level && Config.kind(entry.layout) === "list") found.push(...layoutProblems("sets a layout that", entry.layout, rows, Config.kind(entry.bar) === "map" ? entry.bar : {}, "entry of its level"));
    // A pinned level fits its rows, a list's being its limit; a bar shows its list, opening no level.
    if (entry.height != null && (pinned || inBar && entry.list != null)) found.push("sets height, but " + (pinned ? "is pinned, so fits its rows" : "its list shows in the bar, opening no level"));
    if (entry.list != null && rows.some(row => [].concat(row.key ?? []).some(key => /^[0-9]$/.test(key)))) found.push("binds a digit, reserved for its list");
    if (Array.isArray(entry.cmd) && entry.cmd.length !== keys.length) found.push("pairs keys and commands, so needs as many of each");
    if (action?.pair && keys.length !== 2) found.push("runs '" + entry.action + "' per key of a pair, so needs two keys");
    if (entry.input != null) found.push(...inputProblems(entry, plugins));
    if (entry.input != null && noInput) found.push("sets input, but " + noInput + " shows no input");
    // Only when nothing else is wrong with it, which is often why it does nothing (command for cmd).
    if (!found.length && (does > 1 || does === 0 && !(inBar && entry.status != null)))
      found.push("needs one of cmd, action, submenu, list or view" + (inBar ? ", or only a status" : ""));
    return found;
  }
}
