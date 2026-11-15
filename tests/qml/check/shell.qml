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
    ["a header item neither built in nor a plugin", { menu: { header: { left: ["nope"] } } }, "'nope' is neither built in nor a plugin"],
    ["a list neither built in nor a plugin's", menu([{ key: "x", desc: "X", list: "nope" }]), "names list 'nope'"],
    ["an action that is not built in", menu([{ key: "x", desc: "X", action: "nope" }]), "runs action 'nope'"],
    ["a pair action with one key", menu([{ key: "v", desc: "Volume", action: "sinkVolume" }]), "needs two keys"],
    ["both cmd and action", menu([{ key: "m", desc: "Mute", cmd: "true", action: "sinkMute" }]), "needs one of cmd, action"],
    ["a field no entry takes", menu([{ key: "x", desc: "X", cmd: "true", command: "true" }]), "sets command, which no entry takes"],
    ["a reserved key", menu([{ key: "Escape", desc: "X", cmd: "true" }]), "keys reserved for the menu in the top level: Escape"],
    ["a key bound twice", menu([{ key: "x", desc: "X", cmd: "true" }, { key: "x", desc: "Y", cmd: "true" }]), "keys bound twice in the top level: x"],
    ["a digit beside a list", menu([{ key: "x", desc: "X", list: "tray", submenu: [{ key: "1", desc: "One", icon: "i", cmd: "true" }] }]), "binds a digit"],
    ["a wrong entry in a level below", menu([{ key: "x", desc: "X", submenu: [{ key: "y", desc: "Y", cmd: "true" }] }]), "'X' in the top level holds an action without an icon"]
  ]

  Suite {
    cases: [
      {
        name: "no config, and the starter menu, have nothing wrong",
        until: () => Config.starterEntries.length > 0 && Validation.check({}).length + Validation.check(root.menu(Array.from(Config.starterEntries))).length === 0
      }
    ].concat(root.wrong.map(([what, config, problem]) => ({
      name: what + " is named",
      until: () => Validation.check(config).some(found => found.includes(problem))
    })))
  }
}
