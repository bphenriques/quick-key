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
    ["a rule's app that is no name", { plugins: { notifications: { rules: [{ app: false }] } } }, "rules[0] app takes a string"],
    ["a group named as a given value in another case", { plugins: { notifications: { rules: [{ match: { summary: "(?<App>.*)" } }] } } }, "a group named App, which its commands already get"],
    ["an app icon mode that is none", { theme: { appIcons: "gray" } }, "theme.appIcons is 'gray', not one of colour, grey, tint"],
    ["a setting since renamed", { theme: { monochromeTray: true } }, "theme.monochromeTray is now theme.appIcons"],
    ["a setting since removed", { menu: { edge: "top" } }, "menu.edge is now removed: the menu always sits at the bottom"],
    ["a list setting given as text", { popups: { show: "battery" } }, "popups.show takes a list"],
    ["a submenu that is no list", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: "abc" }] } }, ["sets submenu to a string, not a list", "the top level > A takes a list of entries"]],
    ["an empty row in a submenu", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: [null] }] } }, "holds something that is not an entry"],
    ["a key that is no name", { menu: { header: { right: [{ key: 5, desc: "X", status: "battery" }] } } }, "sets key to a number, not a string or a list"],
    ["a pair of keys holding no name", { menu: { header: { right: [{ key: ["a", 5], desc: "X", status: "battery" }] } } }, "sets key to no key names"],
    ["a field of another kind", { menu: { entries: [{ key: "a", desc: "A", cmd: "true", icon: "x", keepOpen: "yes" }] } }, "sets keepOpen to a string, not a boolean"],
    ["a plugin type that is no name", { plugins: { x: { type: 5 } } }, "x.type takes a plugin's name or path"],
    ["a plugin without a type, its name no shipped one", { plugins: { vpn: { read: "x" } } }, "names type 'vpn', which is neither shipped nor in " + Config.configDir + "/plugins; for a command plugin, set type = \"command\""],
    ["a plugin type that does not exist", { plugins: { x: { type: "niriMinmap" } } }, "names type 'niriMinmap', which is neither shipped"],
    ["a key no keyboard sends", { menu: { entries: [{ key: "Esc", desc: "X", cmd: "true", icon: "x" }] } }, "keys no keyboard sends"],
    ["Ctrl with a symbol", { menu: { entries: [{ key: "Ctrl+.", desc: "X", cmd: "true", icon: "x" }] } }, "keys no keyboard sends"],
    ["a colour that is no colour", { theme: { alert: "rgba(255,0,0,0.5)" } }, "theme.alert: 'rgba(255,0,0,0.5)' is no colour"],
    ["an opacity past 1", { theme: { surfaceOpacity: 2 } }, "theme.surfaceOpacity is 2, not 0 to 1"],
    ["no columns", { menu: { columns: 0 } }, "menu.columns is 0, not 1 to 9"],
    ["battery thresholds the wrong way round", { battery: { low: 5, critical: 50 } }, "battery.critical is 50, not below battery.low"],
    ["a bar slot that is no list", { menu: { header: { left: "battery" } } }, "menu.header.left takes a list"],
    ["a level's bar slot that is no list", menu([{ key: "a", desc: "A", icon: "x", submenu: [], header: { right: "battery" } }]), "menu: the top level > A's header.right takes a list"],
    ["a level's bar slot misspelt", { menu: { entries: [{ key: "a", desc: "A", icon: "x", submenu: [], header: { rigth: [] } }] } }, "bar sets rigth, none of left, center, right"],
    ["a setting the shell does not declare", { audio: { stepp: 1 } }, "audio.stepp is not a setting"],
    ["a value of another kind", { audio: { step: "5" } }, "audio.step takes a number"],
    ["a plugin with two sources", { plugins: { x: { type: "command", watch: "a", read: "b" } } }, "more than one of watch, read and file"],
    ["every without read", { plugins: { x: { type: "command", every: 5 } } }, "sets every without read"],
    ["a plugin with a built-in name", { plugins: { sink: { type: "command" } } }, "takes a built-in name"],
    ["a name in a bar neither a status nor a plugin", { menu: { header: { left: ["nope"] } } }, "'nope' in the top level's bar is neither a status nor a plugin"],
    ["a pop-up that is neither a status nor a plugin", { popups: { show: ["nope"] } }, "popups.show"],
    ["a bar key the body binds with Ctrl", { menu: { header: { left: [{ key: "x", desc: "X", icon: "x", cmd: "true" }] }, entries: [{ key: "Ctrl+x", desc: "Y", icon: "x", cmd: "true" }] } }, "bar keys its body binds with Ctrl too in the top level: x"],
    ["a bar key with a modifier", { menu: { header: { left: [{ key: "Alt+x", desc: "X", icon: "x", cmd: "true" }] } } }, "bar keys with a modifier"],
    ["a limit outside a bar", menu([{ key: "x", desc: "X", icon: "x", list: "tray", limit: 3 }]), "can only set limit on a list in a bar"],
    ["a format without a status", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", format: "{a}" }]), "can only set format with status"],
    ["an entry in the body that only shows a status", menu([{ key: "x", desc: "X", status: "battery" }]), "needs one of cmd, action, submenu, list or view"],
    ["a field misspelt, which is why the entry does nothing", menu([{ key: "l", desc: "Lock", icon: "x", command: "true" }]), "sets command, which no entry takes"],
    ["a list neither built in nor a plugin's", menu([{ key: "x", desc: "X", icon: "x", list: "nope" }]), "names list 'nope'"],
    ["an action that is not built in", menu([{ key: "x", desc: "X", action: "nope" }]), "runs action 'nope'"],
    ["a pair action with one key", menu([{ key: "v", desc: "Volume", action: "sinkVolume" }]), "needs two keys"],
    ["both cmd and action", menu([{ key: "m", desc: "Mute", cmd: "true", action: "sinkMute" }]), "needs one of cmd, action"],
    ["a field no entry takes", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", command: "true" }]), "sets command, which no entry takes"],
    ["a reserved key", menu([{ key: "Escape", desc: "X", icon: "x", cmd: "true" }]), "keys reserved for the menu in the top level: Escape"],
    ["a key bound twice", menu([{ key: "x", desc: "X", icon: "x", cmd: "true" }, { key: "x", desc: "Y", icon: "x", cmd: "true" }]), "keys bound twice in the top level: x"],
    ["a pin that is an id", menu([{ key: "a", desc: "A", icon: "x", list: "sinks", pins: ["bluez_output.*"] }]), "takes each pin as { match, label }"],
    ["a pin without its label", menu([{ key: "a", desc: "A", icon: "x", list: "sinks", pins: [{ match: "bluez_output.*" }] }]), "takes each pin as { match, label }"],
    ["a digit beside a list", menu([{ key: "x", desc: "X", icon: "x", list: "tray", submenu: [{ key: "1", desc: "One", icon: "i", cmd: "true" }] }]), "binds a digit"],
    ["a row of the top level without an icon", menu([{ key: "l", desc: "Lock", cmd: "loginctl lock-session" }]), "'Lock' in the top level needs an icon"],
    ["a wrong entry in a level below", menu([{ key: "x", desc: "X", icon: "x", submenu: [{ key: "y", desc: "Y", cmd: "true" }] }]), "'Y' in the top level > X needs an icon"],
    ["an input on an entry without a level", menu([{ key: "x", desc: "X", icon: "x", cmd: "true", input: { desc: "Add", cmd: "true" } }]), "can only set input on a level with submenu, list or view"],
    ["an input setting a key, which Tab is for every input", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { key: "a", desc: "Add", cmd: "true" } }]), "sets input.key, which no input takes"],
    ["an entry on Tab, which moves to the input", menu([{ key: "Tab", desc: "X", icon: "x", cmd: "true" }]), "keys reserved for the menu in the top level: Tab"],
    ["a top-level input with nowhere for its text", { menu: { input: { desc: "Ask" } } }, "menu.input gives its input's text to nothing"],
    ["an input with nowhere for its text", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add" } }]), "gives its input's text to nothing"],
    ["an input giving its text to both a command and a plugin", { plugins: { p: { type: "command" } }, menu: { entries: [{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", cmd: "true", plugin: "p" } }] } }, "to both input.cmd and input.plugin"],
    ["an input naming a plugin that is not one", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", plugin: "nope" } }]), "plugin 'nope', which is not one"],
    ["an input format without its text", menu([{ key: "x", desc: "X", icon: "x", list: "tray", input: { desc: "Add", cmd: "true", format: "Add it" } }]), "input.format without {text}"],
    ["an ask plugin without its command", { plugins: { a: { type: "ask" } } }, "plugins.a needs ask"],
    ["a plugin setting its plugin does not declare", { plugins: { d: { type: "dunst", activat: "x" } } }, "plugins.d.activat is not a setting"],
    ["a plugin setting of another kind", { plugins: { t: { type: "tasks", syncAfter: "5" } } }, "plugins.t.syncAfter takes a number"],
    ["a glyph that does not exist", { glyphs: { wifii: "x" } }, "glyphs.wifii is not a glyph"],
    ["a glyph of another kind", { glyphs: { batteryLevels: "x" } }, "glyphs.batteryLevels takes a list of glyphs"],
    ["a map where a list is declared", { popups: { show: { a: 1 } } }, "popups.show takes a list"],
    ["entries that are not a list", { menu: { entries: "x" } }, "the top level takes a list of entries"],
    ["an entry that is not one", menu([null]), "the top level holds something that is not an entry"],
    ["a plugin that is not a map of settings", { plugins: { x: "on" } }, "plugins.x takes a map of settings"],
    ["a pop-up named after what every object inherits", { popups: { show: ["toString"] } }, "popups.show: 'toString' is neither a status nor a plugin"],
    ["a status named after what every object inherits", menu([{ key: "x", desc: "X", icon: "x", list: "tray", submenu: [{ key: "a", desc: "A", status: "constructor", cmd: "true" }] }]), "names status 'constructor'"],
    ["a field named after what every object inherits", menu([{ key: "x", desc: "X", cmd: "true", icon: "x", constructor: 1 }]), "sets constructor, which no entry takes"],
    ["a format naming a field its status has not", menu([{ key: "a", desc: "Audio", icon: "x", status: "sink", format: "{device}|{volme}", cmd: "true" }]), "formats {volme}, which sink has not ({device}, {volume})"],
    ["a rule field named after what every object inherits", { plugins: { notifications: { rules: [{ toString: "x" }] } } }, "rules[0] toString is not a setting"],
    ["a volume past what speakers take", { audio: { max: 500 } }, "audio.max is 500, not 1 to 150"],
    ["a closed history past what is kept", { plugins: { notifications: { history: 500 } } }, "plugins.notifications.history is 500, not 0 to 100"],
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
        name: "an input handing a plugin its text, in its format, on a view in a bar has nothing wrong",
        timeout: 0,
        until: () => root.names({ plugins: { agent: { type: "ask", ask: "true" } }, menu: { header: { left: [{ key: "c", desc: "Calendar", status: "clock", view: "calendar", input: { desc: "Add an event", plugin: "agent", format: "Add: {text}", after: "true" } }] } } }, [])
      },
      {
        name: "a top-level input handing a plugin its text has nothing wrong",
        timeout: 0,
        until: () => root.names({ plugins: { agent: { type: "ask", ask: "true" } }, menu: { input: { desc: "Ask", plugin: "agent" } } }, [])
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
        until: () => Validation.renames({ clock: { fmt: "x" } }, { "clock.fmt": "clock.format", "audio.top": "audio.max" }).join() === "clock.fmt is now clock.format"
      }
    ].concat(root.wrong.map(([what, config, problem]) => ({
      name: what + " is named, and nothing else",
      timeout: 0,
      until: () => root.names(config, [].concat(problem))
    })), [
      // A reload would start the suite over, from the file as saved, and never reach its end.
      {
        name: "a save that changes nothing reloads nothing",
        start: () => root.save("{ \"theme\": { \"name\": \"Nord\" } }\n"),
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
