import QtQuick
import Quickshell
import qs.ui
import qs.widgets.menu

// What the menu makes of its entries: a list's digits, key names and hints, and what an action brings.
ShellRoot {
  id: root

  // The key of each item the menu said a key ran.
  property var pressed: []

  Suite {
    cases: [
      {
        name: "pinned items keep their digits, dimmed while absent; the rest follow",
        until: () => JSON.stringify(menu.numbered("devices", [{ match: "b-*", label: "Bee" }, { match: "z-*", label: "Zed" }])
          .map(item => [item.key, item.desc, item.enabled !== false])) === '[["1","Bee",true],["2","Zed",false],["3","a-1",true]]'
      },
      {
        name: "keys show Emacs-style",
        until: () => MenuKeys.label(["Ctrl+Left", "Ctrl+Right"], true) === "C-←→" && MenuKeys.label("Return") === "RET" && MenuKeys.label("Alt+k") === "M-k"
      },
      {
        name: "keys are named as entries declare them: Shift picks the capital, a modifier alone has no name",
        until: () => JSON.stringify([
          { key: Qt.Key_A, modifiers: Qt.ShiftModifier, text: "A" },
          { key: Qt.Key_Left, modifiers: Qt.ControlModifier, text: "" },
          { key: Qt.Key_C, modifiers: Qt.ControlModifier | Qt.AltModifier, text: "\u0003" },
          { key: Qt.Key_Question, modifiers: Qt.ShiftModifier, text: "?" },
          { key: Qt.Key_Shift, modifiers: Qt.ShiftModifier, text: "" }
        ].map(event => MenuKeys.name(event))) === '["A","Ctrl+Left","Ctrl+Alt+c","?",""]'
      },
      {
        name: "an action brings its icon and pairing, and dims with nothing to act on",
        until: () => {
          const [play, track, awake] = menu.itemsOf({ kind: "entry", entry: { submenu: [
            { key: "p", desc: "Play", action: "playPause" },
            { key: ["Left", "Right"], desc: "Track", action: "track", icon: "T" },
            { key: "k", desc: "Keep awake", action: "keepAwake" }
          ] } });
          return play.enabled === false && play.icon === Glyphs.playPause && track.paired && track.icon === "T" && awake.enabled && !awake.active;
        }
      },
      {
        name: "a key that runs a row is told to it, one that cannot run is not",
        start: () => [[Qt.Key_P, "p"], [Qt.Key_X, "x"]].forEach(([key, text]) => menu.handleKey({ key: key, modifiers: Qt.NoModifier, text: text })),
        until: () => root.pressed.join() === "x"
      }
    ]
  }

  Connections {
    target: menu

    function onPressed(item) {
      root.pressed = root.pressed.concat([item.key]);
    }
  }

  MenuModel {
    id: menu
  }
}
