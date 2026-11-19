import QtQuick
import Quickshell
import qs.builtins
import qs.services
import qs.ui
import qs.widgets.menu

// What the menu makes of its entries: a list's digits, key names and hints, what an action brings, the bar's keys and an entry's format.
ShellRoot {
  id: root

  // The legend's keys while an input has the keys.
  property var typingLegend: []

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
        name: "pick shows the level's whole list in the picker, and the chosen item runs as its digit would",
        start: () => {
          menu.push({ kind: "entry", title: "Devices", entry: { list: "devices", submenu: [{ key: "space", desc: "All...", action: "pick" }] } });
          menu.activate(menu.items.find(item => item.key === "space"), "space");
        },
        until: () => Plugins.get("picked")?.text === "b-2"
      },
      {
        name: "Ctrl reaches the bar: its entry by its key",
        start: () => menu.handleKey({ key: Qt.Key_X, modifiers: Qt.ControlModifier, text: "" }),
        until: () => Plugins.get("picked")?.text === "bar"
      },
      {
        name: "a digit with Ctrl picks from the bar's list",
        start: () => menu.handleKey({ key: Qt.Key_1, modifiers: Qt.ControlModifier, text: "" }),
        until: () => Plugins.get("picked")?.text === "a-1"
      },
      {
        name: "past its limit, a bar's list shows the whole list in the picker on 0",
        start: () => menu.handleKey({ key: Qt.Key_0, modifiers: Qt.ControlModifier, text: "" }),
        until: () => Plugins.get("picked")?.text === "b-2"
      },
      {
        name: "Ctrl held lists the bar's keys, each named",
        start: () => menu.held = "Ctrl",
        until: () => JSON.stringify(menu.hints.map(hint => [MenuKeys.label(hint.key), hint.desc])) === '[["C-x","X"],["C-1","a-1"],["C-0","+1"]]'
      },
      {
        name: "a format fills its fields, and a field without a value leaves nothing",
        until: () => Statuses.formatted("{title} · {when}", { title: "Lunch", when: "13:00" }) === "Lunch · 13:00" && Statuses.formatted("{none} x", {}) === "x"
      },
      {
        name: "a plugin's empty list says why, in its words",
        start: () => menu.push({ kind: "entry", entry: { list: "nothing" } }),
        until: () => menu.emptyText === "Nothing found"
      },
      {
        name: "? lists the keys no row shows, and any key closes the list",
        start: () => {
          menu.held = "";
          menu.handleKey({ key: Qt.Key_Question, modifiers: Qt.ShiftModifier, text: "?" });
        },
        until: () => {
          if (menu.hints.length === 0 || MenuKeys.label(menu.hints[0].key) !== "C-") return false;
          menu.handleKey({ key: Qt.Key_X, modifiers: Qt.NoModifier, text: "x" });
          return menu.held === "";
        }
      },
      {
        name: "an input's key gives it the keys, its text reaches its command, and its after runs, given nothing, once the command succeeds",
        start: () => {
          menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Add", cmd: "printf '%s\\n' > \"$XDG_RUNTIME_DIR/picked\"", after: "echo \"done $#\" > \"$XDG_RUNTIME_DIR/followed\"" } } });
          menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          menu.submit("  typed  ", false);
        },
        until: () => menu.inputFocused && Plugins.get("picked")?.text === "typed" && Plugins.get("followed")?.text === "done 0"
      },
      {
        name: "an input naming a plugin gives it its text in its format, the legend showing the input's keys; in the background the menu closes",
        start: () => {
          menu.stack = [];
          menu.push({ kind: "entry", entry: { view: "calendar", input: { desc: "Add an event", plugin: "agent", format: "Add: {text}." } } });
          menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          root.typingLegend = menu.legend.map(key => MenuKeys.label(key.key));
          menu.submit("typed", true);
        },
        until: () => root.typingLegend[0] === "C-S-RET" && menu.stack.length === 0 && Plugins.get("agent")?.exchanges[0]?.reply === "Add: typed."
      },
      {
        name: "an input whose plugin did not load takes nothing, so the menu stays and the input keeps its text",
        until: () => {
          menu.stack = [];
          menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Add", plugin: "gone" } } });
          return menu.submit("kept", true) === false && menu.stack.length === 1;
        }
      },
      {
        name: "an input on a list whose plugin takes no text keeps its text, and the menu stays",
        until: () => {
          menu.stack = [];
          menu.push({ kind: "entry", entry: { list: "devices", input: { desc: "Add" } } });
          return Plugins.get("devices") !== null && menu.submit("kept", true) === false && menu.stack.length === 1;
        }
      },
      {
        name: "in the body Tab moves to the input, and Shift+Tab is left to Qt",
        until: () => {
          menu.stack = [{ kind: "entry", entry: { submenu: [], input: { desc: "Add", cmd: "true" } } }];
          menu.inputFocused = false;
          const backtab = menu.handleKey({ key: Qt.Key_Backtab, modifiers: Qt.ShiftModifier, text: "" });
          const tab = menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          return !backtab && tab && menu.inputFocused;
        }
      },
      {
        name: "each input keeps its own unsent text",
        until: () => {
          const first = { kind: "entry", entry: { submenu: [], input: { desc: "First", cmd: "true" } } };
          menu.stack = [first];
          menu.keepDraft("one");
          menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Second", cmd: "true" } } });
          const second = menu.draft;
          menu.stack = [first];
          return second === "" && menu.draft === "one";
        }
      }
    ]
  }

  MenuModel {
    id: menu
  }
}
