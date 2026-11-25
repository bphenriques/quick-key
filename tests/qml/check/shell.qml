import QtQuick
import Quickshell
import qs

// What the check makes of a config.json: each of `wrong` is what is wrong, a config holding it, and a part of each problem it names, nothing else.
ShellRoot {
  id: root

  function menu(entries) {
    return { menu: { entries: entries } };
  }

  // Whether the check names exactly `problems`, each by a part of it; else what it named, so a failing case says why.
  function names(config, problems) {
    const found = Validation.check(config);
    const right = found.length === problems.length && problems.every(part => found.some(each => each.includes(part)));
    if (!right) console.info("# found " + JSON.stringify(found));
    return right;
  }

  readonly property var wrong: [
    ["a fractional font size", { theme: { fontSize: 11.5 } }, "theme.fontSize is 11.5, not a whole number"],
    ["a margin past any screen", { theme: { edgeMargin: 1000 } }, "theme.edgeMargin is 1000, not 0 to 400"],
    ["a font past any screen", { theme: { fontSize: 500 } }, "theme.fontSize is 500, not 6 to 32"],
    ["padding past any screen", { theme: { padding: 5000 } }, "theme.padding is 5000, not 0 to 50"],
    ["a level of 40 columns", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: [], columns: 40 }] } }, "sets columns to 40, not 1 to 9"],
    ["an app icon mode that is none", { theme: { appIcons: "gray" } }, "theme.appIcons is 'gray', not one of colour, grey, tint"],
    ["a setting since renamed", { theme: { monochromeTray: true } }, "theme.monochromeTray is now theme.appIcons"],
    ["a setting since removed", { menu: { edge: "top" } }, "menu.edge is removed: the menu always sits at the bottom"],
    ["a setting since removed beside a misspelt one", { menu: { edge: "top" }, audio: { stepp: 1 } }, ["menu.edge is removed", "audio.stepp is not a setting"]],
    ["the top level's bar under its old name", { menu: { header: { left: [] } } }, "menu.header is now menu.bar"],
    ["the bar split into islands under its old name", { menu: { islands: true } }, "menu.islands is now menu.splitBar"],
    ["the input's place under its old setting", { menu: { inputSide: "bar" } }, "menu.inputSide is now menu.layout"],
    ["a layout naming no island", { menu: { layout: ["input", "body", "tray"] } }, "menu.layout names 'tray', none of input, body, bar"],
    ["a layout holding a number", { menu: { layout: ["body", 5] } }, "menu.layout holds a number, not an island's name or a pinned level"],
    ["a pin naming no entry", { menu: { layout: ["body", { level: "z" }] } }, "menu.layout pins 'z', which no top-level entry binds"],
    ["a pin naming a key path", { menu: { layout: ["body", { level: "a 2" }] } }, "menu.layout pins 'a 2', a key path"],
    ["a pin naming a bar entry", { menu: { layout: ["body", { level: "c" }] } }, "menu.layout pins 'c', a bar entry"],
    ["a pin without a level", { menu: { layout: ["body", { key: "a" }] } }, ["holds a pinned level setting key", "holds a pinned level without a key"]],
    ["a pin holding its level's setting", { menu: { layout: ["body", { level: "t", limit: 3 }], entries: [{ key: "t", desc: "T", icon: "x", list: "tray" }] } },
      "menu.layout holds a pinned level setting limit, which it does not take: set it on the entry on 't'"],
    ["a pin of an entry without a level", { menu:{ layout: ["body", { level: "x" }], entries: [{ key: "x", desc: "X", icon: "x", cmd: "true" }] } }, "menu.layout pins 'x', which opens no level"],
    ["a pin twice", { menu: { layout: ["body", { level: "t" }, { level: "t" }], entries: [{ key: "t", desc: "T", icon: "x", list: "tray" }] } }, "menu.layout pins 't' more than once"],
    ["a pinned entry's bar, status and format", { menu: { layout: ["body", { level: "t" }], entries: [{ key: "t", desc: "T", icon: "x", list: "tray", status: "battery", format: "{level}", bar: { left: [] } }] } },
      ["'T' in the top level is pinned, so its bar shows nowhere", "is pinned, so its status shows nowhere", "is pinned, so its format shows nowhere"]],
    ["a layout without a body", { menu: { layout: ["input", "bar"] } }, "menu.layout shows no body"],
    ["a layout with two bodies", { menu: { layout: ["body", "body", "bar"] } }, "menu.layout shows body more than once"],
    ["a layout with two inputs", { menu: { layout: ["input", "body", "input"] } }, "menu.layout shows input more than once"],
    ["a layout with two bars", { menu: { layout: ["bar", "body", "bar"] } }, "menu.layout shows bar more than once"],
    ["a top-level input on a layout without one", { plugins: { agent: { type: "ask", ask: "true" } }, menu: { input: { desc: "Ask", plugin: "agent" }, layout: ["body", "bar"] } }, "menu.input is set, but menu.layout shows no input"],
    ["a level's input on a layout without one", { menu: { layout: ["body", "bar"], entries: [{ key: "x", desc: "X", icon: "x", list: "tray", submenu: [{ key: "y", desc: "Y", icon: "x", submenu: [], input: { desc: "Add", cmd: "true" } }] }] } }, "'Y' in the top level > X sets input, but menu.layout shows no input"],
    ["a level's input under an entry's layout without one", menu([{ key: "x", desc: "X", icon: "x", submenu: [{ key: "y", desc: "Y", icon: "x", submenu: [], input: { desc: "Add", cmd: "true" } }], layout: ["body"] }]),
      "'Y' in the top level > X sets input, but its level's layout shows no input"],
    ["an entry's layout naming no island, without a body, with two inputs", menu([{ key: "x", desc: "X", icon: "x", submenu: [], layout: ["input", "input", "tray"] }]),
      ["'X' in the top level sets a layout that names 'tray'", "sets a layout that shows no body", "sets a layout that shows input more than once"]],
    ["an entry's layout pinning what its level does not bind, a key path, a bar entry or a row without a level", menu([{ key: "x", desc: "X", icon: "x", layout: ["body", { level: "t" }, { level: "y z" }, { level: "b" }, { level: "c" }],
      submenu: [{ key: "c", desc: "C", icon: "x", cmd: "true" }], bar: { left: [{ key: "b", desc: "B", icon: "x", cmd: "true" }] } }]),
      ["sets a layout that pins 't', which no entry of its level binds", "pins 'y z', a key path", "pins 'b', a bar entry", "pins 'c', which opens no level"]],
    ["an entry's pinned entry's layout", menu([{ key: "x", desc: "X", icon: "x", layout: ["body", { level: "t" }], submenu: [{ key: "t", desc: "T", icon: "x", list: "tray", layout: ["body"] }] }]),
      "'T' in the top level > X is pinned, so its layout shows nowhere"],
    ["a pin binding another pin's key", { menu: { layout: ["body", { level: "t" }, { level: "w" }], entries: [{ key: "t", desc: "T", icon: "x", submenu: [{ key: "w", desc: "W", icon: "x", cmd: "true" }] }, { key: "w", desc: "Wi-Fi", icon: "x", list: "wifi" }] } },
      "menu: the top level puts two things on w: 'Wi-Fi' and 'W' on pinned t"],
    ["a pin's letter on a letter of the body", { menu: { layout: ["body", { level: "t" }], entries: [{ key: "c", desc: "Calendar", icon: "x", cmd: "true" }, { key: "t", desc: "Tasks", icon: "x", list: "tray", submenu: [{ key: "c", desc: "Done", icon: "x", cmd: "true" }] }] } },
      "menu: the top level puts two things on c: 'Calendar' and 'Done' on pinned t"],
    ["two pinned lists, their digits on one screen", { menu: { layout: ["body", { level: "t" }, { level: "w" }], entries: [{ key: "t", desc: "Tray", icon: "x", list: "tray", limit: 2 }, { key: "w", desc: "Wi-Fi", icon: "x", list: "wifi", limit: 3 }] } },
      "menu: the top level puts two things on 1, 2: 'Tray' on pinned t and 'Wi-Fi' on pinned w"],
    ["a pin's row on a bar key with Ctrl", { menu: { layout: ["body", { level: "t" }], bar: { left: [{ key: "x", desc: "X", icon: "x", cmd: "true" }] }, entries: [{ key: "t", desc: "Tasks", icon: "x", list: "tray", submenu: [{ key: "Ctrl+x", desc: "Cut", icon: "x", cmd: "true" }] }] } },
      "menu: the top level puts two things on Ctrl+x: 'Cut' on pinned t and 'X' on the bar"],
    ["a view's key on a pin", menu([{ key: "c", desc: "Calendar", icon: "x", view: "calendar", layout: ["body", { level: "t" }], submenu: [{ key: "t", desc: "Tasks", icon: "x", list: "tray" }] }]),
      "menu: the top level > Calendar puts two things on t: the calendar view and 'Tasks'"],
    ["a row on a key its level's view takes", menu([{ key: "c", desc: "Calendar", icon: "x", view: "calendar", submenu: [{ key: "t", desc: "Tea", icon: "x", cmd: "true" }, { key: "Right", desc: "Next", icon: "x", cmd: "true" }] }]),
      ["menu: the top level > Calendar puts two things on t: the calendar view and 'Tea'", "menu: the top level > Calendar puts two things on Right: the calendar view and 'Next'"]],
    ["a pinned list on a level that lists", menu([{ key: "w", desc: "Wi-Fi", icon: "x", list: "wifi", layout: ["body", { level: "e" }], submenu: [{ key: "e", desc: "Events", icon: "x", list: "tray", limit: 2 }] }]),
      "menu: the top level > Wi-Fi puts two things on 1, 2: 'wifi' and 'Events' on pinned e"],
    ["a layout on an entry without a level", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", layout: ["body"] }]), "can only set layout on a level"],
    ["a level's bar under its old name", menu([{ key: "a", desc: "A", icon: "x", submenu: [], header: { right: [] } }]), "'A' in the top level sets header, now bar"],
    ["an entry without a key beside a command plugin named as a removed one", { plugins: { notifications: { type: "command", read: "true" } }, menu: { entries: [{ desc: "Lock", icon: "x", cmd: "true" }] } }, "'Lock' in the top level needs a key"],
    ["a list setting given as text", { popups: { show: "battery" } }, "popups.show takes a list"],
    ["a submenu that is no list", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: "abc" }] } }, "sets submenu to a string, not a list"],
    ["an empty row in a submenu", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: [null] }] } }, "holds something that is not an entry"],
    ["a key that is no name", { menu: { bar: { right: [{ key: 5, desc: "X", status: "battery" }] } } }, "sets key to a number, not a string or a list"],
    ["a pair of keys holding no name", { menu: { bar: { right: [{ key: ["a", 5], desc: "X", status: "battery" }] } } }, "sets key to no key names"],
    ["a field of another kind", { menu: { entries: [{ key: "a", desc: "A", cmd: "true", icon: "x", keepOpen: "yes" }] } }, "sets keepOpen to a string, not a boolean"],
    ["a plugin type that is no name", { plugins: { x: { type: 5 } } }, "x.type takes a plugin's name or path"],
    ["a plugin without a type, its name no shipped one", { plugins: { vpn: { read: "x" } } }, "names type 'vpn', which is neither shipped nor in " + Config.configDir + "/plugins; for a command plugin, set type = \"command\""],
    ["a plugin type that does not exist", { plugins: { x: { type: "niriMinmap" } } }, "names type 'niriMinmap', which is neither shipped"],
    ["a key no keyboard sends", { menu: { entries: [{ key: "Esc", desc: "X", cmd: "true", icon: "x" }] } }, "keys no keyboard sends"],
    ["Ctrl with a symbol", { menu: { entries: [{ key: "Ctrl+.", desc: "X", cmd: "true", icon: "x" }] } }, "keys no keyboard sends"],
    ["a colour that is no colour", { theme: { alert: "rgba(255,0,0,0.5)" } }, "theme.alert: 'rgba(255,0,0,0.5)' is no colour"],
    ["an opacity past 1", { theme: { surfaceOpacity: 2 } }, "theme.surfaceOpacity is 2, not 0 to 1"],
    ["no columns", { menu: { columns: 0 } }, "menu.columns is 0, not 1 to 9"],
    ["a height of no whole rows", menu([{ key: "a", desc: "A", icon: "x", submenu: [], height: 2.5 }]), "'A' in the top level sets height to 2.5, not a whole number"],
    ["a height of no rows", { menu: { height: 0 } }, "menu.height is 0, not 1 or more"],
    ["a height as text", { menu: { height: "4" } }, "menu.height takes a number"],
    ["a height as bounds", menu([{ key: "a", desc: "A", icon: "x", submenu: [], height: { min: 2, max: 3 } }]), "sets height to a map, not a number"],
    ["a height beside a limit", { menu: { bar: { right: [{ desc: "Tray", list: "tray", limit: 3, height: 3 }] } } },
      ["'Tray' in the top level's bar cannot combine height with limit", "sets height, but its list shows in the bar, opening no level"]],
    ["a height on a view", menu([{ key: "c", desc: "Calendar", icon: "x", view: "calendar", submenu: [], height: 4 }]), "cannot combine height with view"],
    ["a height on an entry with no rows", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", height: 4 }]), "can only set height with submenu or list"],
    ["a height on a bar entry's list", { menu: { bar: { right: [{ desc: "Tray", list: "tray", height: 3 }] } } }, "sets height, but its list shows in the bar, opening no level"],
    ["a pinned entry's height", { menu: { layout: ["body", { level: "t" }], entries: [{ key: "t", desc: "T", icon: "x", submenu: [], height: 3 }] } }, "'T' in the top level sets height, but is pinned, so fits its rows"],
    ["battery thresholds the wrong way round", { battery: { low: 5, critical: 50 } }, "battery.critical is 50, not below battery.low"],
    ["a bar slot that is no list", { menu: { bar: { left: "battery" } } }, "menu.bar.left takes a list"],
    ["a level's bar slot that is no list", menu([{ key: "a", desc: "A", icon: "x", submenu: [], bar: { right: "battery" } }]), "menu: the top level > A's bar.right takes a list"],
    ["a level's bar slot misspelt", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: [], bar: { rigth: [] } }] } }, "bar sets rigth, none of left, center, right"],
    ["a setting the shell does not declare", { audio: { stepp: 1 } }, "audio.stepp is not a setting"],
    ["a value of another kind", { audio: { step: "5" } }, "audio.step takes a number"],
    ["a plugin with two sources", { plugins: { x: { type: "command", watch: "a", read: "b" } } }, "more than one of watch, read and file"],
    ["a plugin with a built-in name", { plugins: { sink: { type: "command" } } }, "takes a built-in name"],
    ["a plugin named after the menu's IPC target", { plugins: { menu: { type: "command" } } }, "plugins.menu takes a built-in name"],
    ["a plugin named after the inputs' kept drafts", { plugins: { drafts: { type: "ask", ask: "true" } } }, "plugins.drafts takes a built-in name"],
    ["a name in a bar neither a status nor a plugin", { menu: { bar: { left: ["nope"] } } }, "'nope' in the top level's bar is neither a status nor a plugin"],
    ["a pop-up that is neither a status nor a plugin", { popups: { show: ["nope"] } }, "popups.show"],
    ["a bar key the body binds with Ctrl", { menu: { bar: { left: [{ key: "x", desc: "X", icon: "x", cmd: "true" }] }, entries: [{ key: "Ctrl+x", desc: "Y", icon: "x", cmd: "true" }] } }, "menu: the top level puts two things on Ctrl+x: 'Y' and 'X' on the bar"],
    ["a bar key with a modifier", { menu: { bar: { left: [{ key: "Alt+x", desc: "X", icon: "x", cmd: "true" }] } } }, "bar keys with a modifier"],
    ["a limit outside a bar", menu([{ key: "x", desc: "X", icon: "x", list: "tray", limit: 3 }]), "can only set limit on a list in a bar"],
    ["a format without a status", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", format: "{a}" }]), "can only set format with status"],
    ["a bar entry with only its text, which does nothing", { menu: { bar: { left: [{ key: "x", desc: "X" }] } } }, "needs one of cmd, action, submenu, list or view, or only a status"],
    ["an entry in the body that only shows a status", menu([{ key: "x", desc: "X", status: "battery" }]), "needs one of cmd, action, submenu, list or view"],
    ["a field misspelt, which is why the entry does nothing", menu([{ key: "l", desc: "Lock", icon: "x", command: "true" }]), "sets command, which no entry takes"],
    ["a list neither built in nor a plugin's", menu([{ key: "x", desc: "X", icon: "x", list: "nope" }]), "names list 'nope'"],
    ["an action that is not built in", menu([{ key: "x", desc: "X", action: "nope" }]), "runs action 'nope', which is neither built in nor"],
    ["a pair action with one key", menu([{ key: "v", desc: "Volume", action: "sinkVolume" }]), "needs two keys"],
    ["both cmd and action", menu([{ key: "m", desc: "Mute", cmd: "true", action: "sinkMute" }]), "needs one of cmd, action"],
    ["a field no entry takes", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", command: "true" }]), "sets command, which no entry takes"],
    ["a legend naming no key", menu([{ key: "c", desc: "Calendar", icon: "x", view: "calendar", legend: ["Ctrl+up", "Page_Down"] }]), "legend names no key as ? names them (Ctrl+Up, Page_Down): Ctrl+up"],
    ["a legend on an entry without a level", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", legend: ["Escape"] }]), "can only set legend on a level"],
    ["a plugin's legend naming no key", { plugins: { x: { type: "command", legend: ["PgDn"] } } }, "plugins.x.legend names no key as ? names them (Ctrl+Up, Page_Down): PgDn"],
    ["a reserved key", menu([{ key: "Escape", desc: "X", icon: "x", cmd: "true" }]), "keys reserved for the menu in the top level: Escape"],
    ["a key bound twice", menu([{ key: "x", desc: "X", icon: "x", cmd: "true" }, { key: "x", desc: "Y", icon: "x", cmd: "true" }]), "menu: the top level puts two things on x: 'X' and 'Y'"],
    ["a pin that is an id", menu([{ key: "a", desc: "A", icon: "x", list: "sinks", pins: ["bluez_output.*"] }]), "takes each pin as { match, label }"],
    ["a pin without its label", menu([{ key: "a", desc: "A", icon: "x", list: "sinks", pins: [{ match: "bluez_output.*" }] }]), "takes each pin as { match, label }"],
    ["a digit beside a list", menu([{ key: "x", desc: "X", icon: "x", list: "tray", submenu: [{ key: "1", desc: "One", icon: "i", cmd: "true" }] }]), "binds a digit"],
    ["a wrong entry in a level below", menu([{ key: "x", desc: "X", icon: "x", submenu: [{ desc: "Y", icon: "x", cmd: "true" }] }]), "'Y' in the top level > X needs a key"],
    ["an input on an entry without a level", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", input: { desc: "Add", cmd: "true" } }]), "can only set input on a level with submenu, list or view"],
    ["an input setting a key, which Tab is for every input", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { key: "a", desc: "Add", cmd: "true" } }]), "sets input.key, which no input takes"],
    ["an entry on Tab, which moves to the input", menu([{ key: "Tab", desc: "X", icon: "x", cmd: "true" }]), "keys reserved for the menu in the top level: Tab"],
    ["a top-level input with nowhere for its text", { menu: { input: { desc: "Ask" } } }, "menu.input gives its input's text to nothing"],
    ["an input with nowhere for its text", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add" } }]), "gives its input's text to nothing"],
    ["an input giving its text to both a command and a plugin", { plugins: { p: { type: "command" } }, menu: { entries: [{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", cmd: "true", plugin: "p" } }] } }, "to both input.cmd and input.plugin"],
    ["an input naming a plugin that is not one", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", plugin: "nope" } }]), "plugin 'nope', which is not one"],
    ["an input format, now its context", Object.assign(menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", plugin: "agent", format: "Add: {text}" } }]), { plugins: { agent: { type: "ask", ask: "true" } } }), "sets input.format, now input.context"],
    ["an input context given to a command", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", cmd: "true", context: "Tasks" } }]), "sets input.context, which only a plugin is told"],
    ["an ask plugin without its command", { plugins: { a: { type: "ask" } } }, "plugins.a needs ask"],
    ["a plugin setting its plugin does not declare", { plugins: { d: { type: "dunst", activat: "x" } } }, "plugins.d.activat is not a setting"],
    ["a plugin setting of another kind", { plugins: { t: { type: "tasks", syncAfter: "5" } } }, "plugins.t.syncAfter takes a number"],
    ["a glyph that does not exist", { glyphs: { wifii: "x" } }, "glyphs.wifii is not a glyph"],
    ["a glyph of another kind, as config.json sets it too", { glyphs: { batteryLevels: "x" } }, "glyphs.batteryLevels takes a list of glyphs"],
    ["a map where a list is declared", { popups: { show: { a: 1 } } }, "popups.show takes a list"],
    ["entries that are not a list", { menu: { entries: "x" } }, "the top level takes a list of entries"],
    ["an entry that is not one", menu([null]), "the top level holds something that is not an entry"],
    ["a plugin that is not a map of settings", { plugins: { x: "on" } }, "plugins.x takes a map of settings"],
    ["a pop-up named after what every object inherits", { popups: { show: ["toString"] } }, "popups.show: 'toString' is neither a status nor a plugin"],
    ["a status named after what every object inherits", menu([{ key: "x", desc: "X", icon: "x", list: "tray", submenu: [{ key: "a", desc: "A", status: "constructor", cmd: "true" }] }]), "names status 'constructor'"],
    ["a field named after what every object inherits", menu([{ key: "x", desc: "X", cmd: "true", icon: "x", constructor: 1 }]), "sets constructor, which no entry takes"],
    ["a format naming a field its status has not", menu([{ key: "a", desc: "Audio", icon: "x", status: "sink", format: "{device}|{volme}", cmd: "true" }]), "formats {volme}, which sink has not ({device}, {volume})"],
    ["a volume past what speakers take", { audio: { max: 500 } }, "audio.max is 500, not 1 to 150"],
    ["a glyph named after what every object inherits", { glyphs: { objectName: "x" } }, "glyphs.objectName is not a glyph"],
    ["an ask toolMatch that is not a pattern", { plugins: { a: { type: "ask", ask: "true", toolMatch: "([(" } } }, "plugins.a sets toolMatch to what is not a regular expression"],
    ["a music title pattern that is not one", { music: { titleMatch: "([(" } }, "music.titleMatch: '([(' is no regular expression"],
    ["a look that is not one", { plugins: { x: { type: "command", show: { "true": "x" } } } }, "plugins.x.show.true takes a map"],
    ["an item without a string id", { plugins: { x: { type: "command", items: [{ id: 1 }] } } }, "plugins.x.items[0] takes a map with a string id"],
    ["a tasks sort it does not have", { plugins: { t: { type: "tasks", sort: "date" } } }, "plugins.t.sort is 'date', not one of due, priority, title, list"],
    ["a command ending in ;, which would run its first argument", { calendar: { remind: "notify-send x ;\n" } }, "calendar.remind ends in ';'"],
    ["a plugin's command ending in &&", { plugins: { t: { type: "tasks", done: "todo done &&" } } }, "plugins.t.done ends in '&&'"],
    ["an input's command ending in a pipe", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", cmd: "add |" } }]), "input.cmd ends in '|'"]
  ]

  Suite {
    cases: [
      {
        name: "no config, and the starter menu, have nothing wrong",
        until: () => Config.starterEntries.length > 0 && root.names({}, []) && root.names(root.menu(Array.from(Config.starterEntries)), [])
      },
      {
        name: "an input handing a plugin its text and context, on a view in a bar has nothing wrong",
        timeout: 0,
        until: () => root.names({ plugins: { agent: { type: "ask", ask: "true" } }, menu: { bar: { left: [{ key: "c", desc: "Calendar", status: "clock", view: "calendar", input: { desc: "Add an event", plugin: "agent", context: "Calendar", after: "true" } }] } } }, [])
      },
      {
        name: "a top-level input handing a plugin its text has nothing wrong",
        timeout: 0,
        until: () => root.names({ plugins: { agent: { type: "ask", ask: "true" } }, menu: { input: { desc: "Ask", plugin: "agent" } } }, [])
      },
      {
        name: "a layout in any order, or without an input or a bar, has nothing wrong",
        timeout: 0,
        until: () => root.names({ menu: { layout: ["bar", "body", "input"] } }, []) && root.names({ menu: { layout: ["body"] } }, [])
      },
      {
        name: "a pinned list with a limit, and a pin of a starter entry, have nothing wrong",
        timeout: 0,
        until: () => root.names({ menu: { layout: ["input", { level: "t" }, "body", "bar"], entries: [{ key: "t", desc: "T", icon: "x", list: "tray", limit: 3, input: { desc: "Add", cmd: "true" } }] } }, [])
          && root.names({ menu: { layout: [{ level: "a" }, "body"] } }, [])
      },
      {
        name: "an entry's layout, in a bar too, pinning its level's own list with an input, shows inputs past a top layout without one",
        timeout: 0,
        until: () => root.names({ menu: { layout: ["body", "bar"], entries: [{ key: "x", desc: "X", icon: "x", layout: ["input", { level: "t" }, "body"],
          submenu: [{ key: "t", desc: "T", icon: "x", list: "tray", limit: 3, input: { desc: "Add", cmd: "true" } }, { key: "y", desc: "Y", icon: "x", submenu: [], input: { desc: "Add", cmd: "true" } }] }],
          bar: { left: [{ key: "c", desc: "Calendar", status: "clock", view: "calendar", layout: ["input", "body", "bar"] }] } } }, [])
      },
      {
        name: "a height in rows on the top level, a submenu, a list and a bar entry opening a level has nothing wrong",
        timeout: 0,
        until: () => root.names({ menu: { height: 4, entries: [{ key: "a", desc: "A", icon: "x", submenu: [], height: 5 }, { key: "b", desc: "B", icon: "x", list: "tray", height: 2 }],
          bar: { left: [{ key: "s", desc: "S", icon: "x", submenu: [], height: 3 }] } } }, [])
      },
      {
        name: "a row without an icon has nothing wrong",
        timeout: 0,
        until: () => root.names(root.menu([{ key: "l", desc: "Lock", cmd: "true" }]), [])
      },
      {
        name: "a bar entry showing only its text has nothing wrong",
        timeout: 0,
        until: () => root.names({ menu: { bar: { left: [{ key: "x", desc: "Lock", cmd: "true" }] } } }, [])
      },
      {
        name: "a plugin's own settings have nothing wrong",
        timeout: 0,
        until: () => root.names({ plugins: { t: { type: "tasks", add: "true", sync: "true" } } }, [])
      },
      {
        name: "a command ending in an escaped semicolon has nothing wrong",
        timeout: 0,
        until: () => root.names({ calendar: { remind: "find . -exec echo {} \\;" } }, [])
      },
      {
        name: "a theme name that is neither yours nor shipped (config.json's Nord) names the presets",
        until: () => Config.themeWarning.includes("theme Nord not found") && Config.themeWarning.includes("nor a preset: catppuccin-latte, catppuccin-mocha")
      },
      {
        name: "an entry with a desc but no key is said to need only a key",
        timeout: 0,
        until: () => Validation.check(root.menu([{ desc: "Lock", icon: "x", cmd: "true" }])).join() === "menu: 'Lock' in the top level needs a key"
      },
      {
        name: "a key renamed is named with what to write instead, and one not set is not",
        until: () => Validation.renames({ clock: { fmt: "x" } }, { "clock.fmt": "now clock.format", "audio.top": "now audio.max" }).join() === "clock.fmt is now clock.format"
      }
    ].concat(root.wrong.map(([what, config, problem]) => ({
      name: what + " is named, and nothing else",
      timeout: 0,
      until: () => root.names(config, [].concat(problem))
    })), [
      // A reload would start the suite over, from the file as saved, and never reach its end.
      {
        name: "a save that changes nothing reloads nothing",
        start: () => root.save("{ \"theme\": { \"name\": \"Nord\" }, \"glyphs\": { \"batteryLevels\": \"x\" } }\n"),
        until: () => Date.now() - root.saved > 1000
      },
      {
        name: "a save caught halfway keeps the running config",
        start: () => root.save("{ \"theme\": "),
        until: () => Date.now() - root.saved > 1000
      }
    ])
  }

  property real saved: 0

  // Over the copy from the store, which is read-only, as an editor saves: written aside, then moved over it.
  function save(text) {
    saved = Date.now();
    Quickshell.execDetached(["sh", "-c", "printf %s \"$2\" > \"$1.new\" && mv -f \"$1.new\" \"$1\"", "sh", Config.configDir + "/config.json", text]);
  }
}
