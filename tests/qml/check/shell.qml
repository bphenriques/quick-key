import QtQuick
import Quickshell
import qs

// What the check makes of a config.json: each of `wrong` is what is wrong, a config holding it, and a part of the problem it must name.
ShellRoot {
  id: root

  function menu(entries) {
    return { menu: { entries: entries } };
  }

  readonly property var wrong: [
    ["a setting the shell does not declare", { audio: { stepp: 1 } }, "audio.stepp is not a setting"],
    ["a value of another kind", { audio: { step: "5" } }, "audio.step takes a number"],
    ["a plugin with two sources", { plugins: { x: { watch: "a", read: "b" } } }, "more than one of watch, read and file"],
    ["every without read", { plugins: { x: { every: 5 } } }, "sets every without read"],
    ["a plugin with a built-in name", { plugins: { sink: {} } }, "takes a built-in name"],
    ["a name in a bar neither a status nor a plugin", { menu: { header: { left: ["nope"] } } }, "'nope' in the top level's bar is neither a status nor a plugin"],
    ["a bar key the body binds with Ctrl", { menu: { header: { left: [{ key: "x", desc: "X", cmd: "true" }] }, entries: [{ key: "Ctrl+x", desc: "Y", cmd: "true" }] } }, "bar keys its body binds with Ctrl too in the top level: x"],
    ["a bar key with a modifier", { menu: { header: { left: [{ key: "Alt+x", desc: "X", cmd: "true" }] } } }, "bar keys with a modifier"],
    ["a limit outside a bar", menu([{ key: "x", desc: "X", list: "tray", limit: 3 }]), "can only set limit on a list in a bar"],
    ["a format without a status", menu([{ key: "x", desc: "X", cmd: "true", format: "{a}" }]), "can only set format with status"],
    ["an entry in the body that only shows a status", menu([{ key: "x", desc: "X", status: "battery" }]), "needs one of cmd, action, or submenu and/or list or view"],
    ["a list neither built in nor a plugin's", menu([{ key: "x", desc: "X", list: "nope" }]), "names list 'nope'"],
    ["an action that is not built in", menu([{ key: "x", desc: "X", action: "nope" }]), "runs action 'nope'"],
    ["a pair action with one key", menu([{ key: "v", desc: "Volume", action: "sinkVolume" }]), "needs two keys"],
    ["both cmd and action", menu([{ key: "m", desc: "Mute", cmd: "true", action: "sinkMute" }]), "needs one of cmd, action"],
    ["a field no entry takes", menu([{ key: "x", desc: "X", cmd: "true", command: "true" }]), "sets command, which no entry takes"],
    ["a reserved key", menu([{ key: "Escape", desc: "X", cmd: "true" }]), "keys reserved for the menu in the top level: Escape"],
    ["a key bound twice", menu([{ key: "x", desc: "X", cmd: "true" }, { key: "x", desc: "Y", cmd: "true" }]), "keys bound twice in the top level: x"],
    ["a digit beside a list", menu([{ key: "x", desc: "X", list: "tray", submenu: [{ key: "1", desc: "One", icon: "i", cmd: "true" }] }]), "binds a digit"],
    ["a wrong entry in a level below", menu([{ key: "x", desc: "X", submenu: [{ key: "y", desc: "Y", cmd: "true" }] }]), "'X' in the top level holds an action without an icon"],
    ["an input on an entry without a level", menu([{ key: "x", desc: "X", cmd: "true", input: { key: "a", desc: "Add", cmd: "true" } }]), "can only set input on a level with submenu, list or view"],
    ["an input whose key is not a letter", menu([{ key: "x", desc: "X", list: "tray", input: { key: "1", desc: "Add", cmd: "true" } }]), "needs an input with a letter for its key"],
    ["an input on a key its level binds", menu([{ key: "x", desc: "X", submenu: [{ key: "a", desc: "A", icon: "i", cmd: "true" }], input: { key: "a", desc: "Add", cmd: "true" } }]), "binds its input's key twice"],
    ["an input on a key its view takes", menu([{ key: "c", desc: "Calendar", view: "calendar", input: { key: "t", desc: "Add", cmd: "true" } }]), "binds its input's key twice"],
    ["an input with nowhere for its text", menu([{ key: "x", desc: "X", list: "tray", input: { key: "a", desc: "Add" } }]), "gives its input's text to nothing"],
    ["an input giving its text to both a command and a plugin", { plugins: { p: {} }, menu: { entries: [{ key: "x", desc: "X", list: "tray", input: { key: "a", desc: "Add", cmd: "true", plugin: "p" } }] } }, "to both input.cmd and input.plugin"],
    ["an input naming a plugin that is not one", menu([{ key: "x", desc: "X", list: "tray", input: { key: "a", desc: "Add", plugin: "nope" } }]), "plugin 'nope', which is not one"],
    ["an input format without its text", menu([{ key: "x", desc: "X", list: "tray", input: { key: "a", desc: "Add", cmd: "true", format: "Add it" } }]), "input.format without {text}"],
    ["an ask plugin without its command", { plugins: { a: { type: "ask" } } }, "plugins.a needs ask"],
    ["a glyph that does not exist", { glyphs: { wifii: "x" } }, "glyphs.wifii is not a glyph"],
    ["a glyph of another kind", { glyphs: { batteryLevels: "x" } }, "glyphs.batteryLevels takes a list of glyphs"]
  ]

  Suite {
    cases: [
      {
        name: "no config, and the starter menu, have nothing wrong",
        until: () => Config.starterEntries.length > 0 && Validation.check({}).length + Validation.check(root.menu(Array.from(Config.starterEntries))).length === 0
      },
      {
        name: "an input handing a plugin its text, in its format, on a view in a bar has nothing wrong",
        until: () => Validation.check({ plugins: { agent: { type: "ask", ask: "true" } }, menu: { header: { left: [{ key: "c", desc: "Calendar", status: "clock", view: "calendar", input: { key: "a", desc: "Add an event", plugin: "agent", format: "Add: {text}", after: "true" } }] } } }).length === 0
      }
    ].concat(root.wrong.map(([what, config, problem]) => ({
      name: what + " is named",
      until: () => Validation.check(config).some(found => found.includes(problem))
    })))
  }
}
