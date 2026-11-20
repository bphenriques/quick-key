import QtQuick
import Quickshell
import qs.builtins
import qs.services
import qs.ui
import qs.widgets.menu

// What the menu makes of its entries: a list's digits, key names and hints, what an action brings, the bar's keys, an entry's format and the picker over a list.
ShellRoot {
  id: root

  // The legend's keys while an input has the keys.
  property var typingLegend: []
  property int visitStep: 0
  property int orderStep: 0
  // Whether a case pressed its key, once.
  property bool pressed: false
  // Whether Escape out of a level opened to pick showed what opened it.
  property bool backed: false

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
        name: "pick filters the level's list in place, its rows held, and a digit runs its row as at rest",
        start: () => {
          menu.push({ kind: "entry", title: "Devices", entry: { list: "devices", submenu: [{ key: "space", desc: "All...", action: "pick" }] } });
          menu.activate(menu.items.find(item => item.key === "space"), "space");
        },
        until: () => {
          if (!root.pressed && menu.filtering && menu.filterSlots === 2 && menu.rows.length === 2) root.pressed = menu.filterKey("2");
          return root.pressed && Plugins.get("picked")?.text === "b-2";
        }
      },
      {
        name: "Ctrl reaches the bar: its entry by its key",
        start: () => {
          menu.hide();
          menu.handleKey({ key: Qt.Key_X, modifiers: Qt.ControlModifier, text: "" });
        },
        until: () => Plugins.get("picked")?.text === "bar"
      },
      {
        name: "a digit with Ctrl picks from the bar's list",
        start: () => menu.handleKey({ key: Qt.Key_1, modifiers: Qt.ControlModifier, text: "" }),
        until: () => Plugins.get("picked")?.text === "a-1"
      },
      {
        name: "past its limit, a bar's list shows the whole list on 0, on a level of its own filtering from the start",
        start: () => menu.handleKey({ key: Qt.Key_0, modifiers: Qt.ControlModifier, text: "" }),
        until: () => {
          if (root.pressed && menu.level?.picking && menu.filtering && menu.filterSlots === 9 && menu.rows.length === 2) root.pressed = !menu.filterKey("2");
          return !root.pressed && Plugins.get("picked")?.text === "b-2";
        }
      },
      {
        name: "Escape on an empty filter gives the level back at rest, and leaves a level opened to pick for what opened it",
        until: () => {
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "devices" } });
          menu.startFilter();
          const filtered = menu.filtering;
          menu.leaveFilter();
          const rest = !menu.filtering && menu.stack.length === 1;
          Picker.pick("devices", () => root.backed = true);
          const picking = menu.stack.length === 2 && menu.filtering;
          menu.leaveFilter();
          return filtered && rest && picking && !menu.open && root.backed;
        }
      },
      {
        name: "a list of 10000 opens and filters without a stall",
        until: () => {
          if (Plugins.get("many")?.items.length !== 10000) return false;
          menu.hide();
          let start = Date.now();
          menu.pickList("many", null);
          const opened = menu.rows.length;
          const open = Date.now() - start;
          start = Date.now();
          menu.filter.query = "item 99";
          const filtered = menu.rows.length;
          const filter = Date.now() - start;
          start = Date.now();
          for (let i = 0; i < 100; i++) menu.filter.move(1);
          const move = (Date.now() - start) / 100;
          console.info("# 10000 items: open " + open + " ms, filter " + filter + " ms, move " + move + " ms");
          return opened === 9 && filtered === 9 && open < 250 && filter < 50 && move < 5;
        }
      },
      {
        name: "the filter keeps the rows whose label holds every word, case aside; a digit never types",
        start: () => menu.filter.query = "99 ITEM",
        until: () => menu.filter.found.length === 280 && menu.rows[0].desc === "Item 99" && menu.filter.count === "1-9 of 280" && menu.filterKey("5") && menu.filter.query === "99 ITEM"
      },
      {
        name: "nothing matching says so, in the rows' place",
        start: () => menu.filter.query = "plumb",
        until: () => menu.rows.length === 0 && menu.emptyText === "Nothing matches plumb"
      },
      {
        name: "while filtering, the digits label the rows shown and move with the cursor, its row lit",
        start: () => {
          menu.filter.query = "";
          menu.filter.move(10);
        },
        until: () => menu.filter.index === 10 && menu.filter.first === 2 && menu.rows[0].desc === "Item 2" && menu.rows[8].key === "9" && menu.rows[8].desc === "Item 10" && menu.rows[8].current
      },
      {
        name: "the pick row says how many rows show at rest of all the list holds",
        start: () => menu.stack = [{ kind: "entry", entry: { list: "many", submenu: [{ key: "/", desc: "All...", action: "pick" }] } }],
        until: () => menu.actions[0]?.detail === "1-9 of 10000"
      },
      {
        name: "the cursor stays on its item as the list changes",
        start: () => {
          Quickshell.execDetached(["sh", "-c", `echo '{"items": [{"id": "a"}, {"id": "b"}, {"id": "c"}]}' > "$XDG_RUNTIME_DIR/ordered"`]);
          menu.hide();
          menu.pickList("ordered", null);
        },
        until: () => {
          if (root.orderStep === 0 && menu.filter.items.length === 3) {
            menu.filter.move(1);
            root.orderStep = 1;
            Quickshell.execDetached(["sh", "-c", `echo '{"items": [{"id": "z"}, {"id": "a"}, {"id": "b"}, {"id": "c"}]}' > "$XDG_RUNTIME_DIR/ordered"`]);
          }
          return root.orderStep === 1 && menu.filter.items.length === 4 && menu.filter.item?.id === "b" && menu.filter.index === 2;
        }
      },
      {
        name: "while filtering, an item's verb names Return, and Alt opens its own menu, whose keys run its plugin's actions and step back",
        start: () => {
          menu.hide();
          menu.pickList("acting", null);
        },
        until: () => {
          if (menu.rows.length !== 1) return false;
          const legend = menu.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join(", ");
          const counted = menu.filter.count;
          menu.filterKey("Alt+1");
          const own = menu.level.kind === "actions" && menu.items[0].key === "d" && menu.barSlots.left[0].desc === "A";
          menu.handleName("d");
          return legend === "1 choose, ↑ move, RET open, M-RET menu, ESC back" && counted === "1 of 1" && own && menu.level.picking && menu.filtering && Plugins.get("picked")?.text === "a d";
        }
      },
      {
        name: "at rest, Alt with an item's digit opens its own menu too",
        until: () => {
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "acting" } });
          if (menu.rows.length !== 1) return false;
          menu.handleKey({ key: Qt.Key_1, modifiers: Qt.AltModifier, text: "" });
          const opened = menu.level.kind === "actions";
          menu.hide();
          return opened;
        }
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
        name: "an input naming a plugin gives it its text in its format, the legend showing only its Escape; in the background the menu closes",
        start: () => {
          menu.stack = [];
          menu.push({ kind: "entry", entry: { view: "calendar", input: { desc: "Add an event", plugin: "agent", format: "Add: {text}." } } });
          menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          root.typingLegend = menu.legend.map(key => MenuKeys.label(key.key));
          menu.submit("typed", true);
        },
        until: () => root.typingLegend.length === 1 && root.typingLegend[0] === "ESC" && menu.stack.length === 0 && Plugins.get("agent")?.exchanges[0]?.reply === "Add: typed."
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
        name: "a visit's first message takes the input's format, the answer to it as typed; expanding holds the visit, and stepping back returns to the level with the input focused",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent || agent.busy) return false;
          switch (root.visitStep) {
          case 0:
            menu.stack = [{ kind: "entry", entry: { submenu: [], input: { desc: "Add", plugin: "agent", format: "Add: {text}." } } }];
            menu.open = true;
            Plugins.watching = menu.watching;
            root.visitStep = menu.submit("one", false) ? 1 : -1;
            return false;
          case 1:
            root.visitStep = agent.turn?.text === "Add: one." && menu.submit("two", false) ? 2 : -1;
            return false;
          case 2:
            if (agent.turn?.text !== "two") return false;
            const token = menu.watching;
            menu.answerFocused = true;
            menu.handleKey({ key: Qt.Key_Return, modifiers: Qt.NoModifier, text: "\r" });
            const held = agent.shown && menu.expandedWatching === token;
            menu.hide();
            const holding = Plugins.watching === menu.watching && menu.watching === token;
            agent.typing = false;
            agent.act("Escape");
            root.visitStep = held && holding && menu.open && menu.stack.length === 1 && menu.inputFocused && menu.expandedWatching === "" && agent.turn?.text === "two" ? 3 : -1;
            return false;
          }
          menu.hide();
          Plugins.watching = "";
          return root.visitStep === 3;
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
      },
      {
        name: "C-r in an input to a plugin that recalls lists its conversations on a level over it, filtering, and ? names it",
        until: () => {
          menu.hide();
          menu.stack = [{ kind: "entry", entry: { submenu: [], input: { desc: "Ask", plugin: "agent" } } }];
          const named = menu.help.some(key => key.key === "Ctrl+r");
          return named && menu.recall() && menu.stack.length === 2 && menu.level.picking && menu.level.entry.list === "agent" && menu.filtering;
        }
      },
      {
        name: "a key path runs from the top level as typing it would, and the key map lists every path",
        until: () => {
          menu.hide();
          const ran = menu.press("Ctrl+x");
          const missing = menu.press("Ctrl+x nope");
          const map = menu.keyMap();
          return ran && !missing && map.includes("- `Ctrl+x` X") && Plugins.get("picked")?.text === "bar";
        }
      }
    ]
  }

  MenuModel {
    id: menu
  }
}
