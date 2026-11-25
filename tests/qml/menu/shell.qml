import QtQuick
import Quickshell
import qs
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
  // What a case found as it acted, once; null until it has.
  property var acted: null
  property bool pathRan: false
  property bool pathClosed: false
  // The keyed plugin's action a key ran.
  property string ran: ""

  // A level where each key reaches something else: a row, the bar, a listed item and its own menu, the input.
  readonly property var keyedLevel: ({ kind: "entry", entry: { list: "keyed", input: { desc: "Add", cmd: "true" },
    submenu: [{ key: "f", desc: "Row", action: "row" }, { key: "Ctrl+y", desc: "Body", action: "row" }],
    bar: { left: [{ key: "x", desc: "Bar", action: "bar" }, { key: "y", desc: "Shadowed", action: "bar" }, { desc: "Keyed", list: "keyed" }] } } })
  readonly property var bareLevel: ({ kind: "entry", entry: { list: "keyed" } })
  readonly property var slashLevel: ({ kind: "entry", entry: { list: "keyed", submenu: [{ key: "/", desc: "Slash", action: "row" }] } })
  readonly property var calendarLevel: ({ kind: "entry", entry: { view: "calendar", list: "keyed", submenu: [{ key: "Right", desc: "Right", action: "row" }] } })
  readonly property var downLevel: ({ kind: "entry", entry: { list: "keyed", submenu: [{ key: "Down", desc: "Down", action: "row" }] } })
  // A menu's grid of rows, two columns, a capital among them (rule 6).
  readonly property var gridLevel: ({ kind: "actions", title: "Grid", actions: [{ key: "f", desc: "Row", select: () => root.ran = "row" },
    { key: "R", desc: "Capital", select: () => root.ran = "capital" }, { key: "g", desc: "Third", select: () => root.ran = "third" }] })
  readonly property var startFilter: () => menu.body.startFilter()
  readonly property var cursorDown: () => menu.cursorKey("Down")
  readonly property var cursorCapital: () => menu.cursorKey("Down") && menu.cursorKey("Right")

  // What a key does, by precedence: the level it opens on, what is done first, the key, and what it runs.
  readonly property var keyed: [
    ["? lists the keys", keyedLevel, null, "?", "help"],
    ["while the help shows, a row's letter only closes it", keyedLevel, () => menu.hold("Help"), "f", "help closed"],
    ["while the help shows, ? closes it too", keyedLevel, () => menu.hold("Help"), "?", "help closed"],
    ["Escape goes back a level", keyedLevel, null, "Escape", "back"],
    ["Escape on an empty input gives the keys to the body, staying on the level", keyedLevel, () => menu.focusOn("input"), "Escape", "body"],
    ["a view takes its keys before the level's rows", calendarLevel, null, "Right", "view"],
    ["Tab moves to the input", keyedLevel, null, "Tab", "input"],
    ["Tab with no input does nothing", bareLevel, null, "Tab", "nothing"],
    ["a row's letter runs it", keyedLevel, null, "f", "row"],
    ["a digit runs its listed item", keyedLevel, null, "1", "item"],
    ["a digit past the list does nothing", keyedLevel, null, "5", "nothing"],
    ["/ filters the list", keyedLevel, null, "/", "filter"],
    ["/ runs a row bound to it rather than filter", slashLevel, null, "/", "row"],
    ["Alt and a digit open its item's own menu", keyedLevel, null, "Alt+1", "item menu"],
    ["Ctrl and a letter run the bar's entry", keyedLevel, null, "Ctrl+x", "bar"],
    ["Ctrl and a letter the body binds run the body's row", keyedLevel, null, "Ctrl+y", "row"],
    ["Ctrl and a digit run the bar list's item", keyedLevel, null, "Ctrl+1", "item"],
    ["Ctrl, Alt and a digit open the bar item's own menu", keyedLevel, null, "Ctrl+Alt+1", "item menu"],
    ["a bar letter without Ctrl does nothing", keyedLevel, null, "x", "nothing"],
    ["while filtering, a digit runs the row shown", keyedLevel, startFilter, "1", "item"],
    ["while filtering, Alt and a digit open its item's own menu", keyedLevel, startFilter, "Alt+1", "item menu"],
    ["while filtering, a letter is left to the text", keyedLevel, startFilter, "f", "nothing"],
    ["↓ moves a cursor onto the list where no row binds it", keyedLevel, null, "Down", "cursor 1"],
    ["Return runs the cursor's item", keyedLevel, cursorDown, "Return", "item"],
    ["Alt+Return opens the cursor's item's own menu", keyedLevel, cursorDown, "Alt+Return", "item menu"],
    ["a level binding ↓ runs its row rather than move the cursor", downLevel, null, "Down", "row"],
    ["Escape with a cursor goes back at once", keyedLevel, cursorDown, "Escape", "back"],
    ["→ on a list level moves nothing", keyedLevel, null, "Right", "nothing"],
    ["↓ moves a cursor onto a grid's first row", gridLevel, null, "Down", "cursor f"],
    ["→ moves the grid's cursor by one", gridLevel, cursorDown, "Right", "cursor R"],
    ["↓ moves the grid's cursor by its columns", gridLevel, cursorDown, "Down", "cursor g"],
    ["Return runs the grid's row as its letter would", gridLevel, cursorDown, "Return", "row"],
    ["Return on a capital's row does nothing", gridLevel, cursorCapital, "Return", "nothing"],
    ["Shift+Return runs a capital's row", gridLevel, cursorCapital, "Shift+Return", "capital"],
    ["Shift+Return on a lowercase row does nothing", gridLevel, cursorDown, "Shift+Return", "nothing"]
  ]

  // What the key did, told by what changed; the keyed item closes the menu, which is how a run of it shows.
  function outcome(handled, was) {
    if (ran) return ran;
    if (!menu.open) return "item";
    if (menu.level?.kind === "actions" && menu.levels.length > was.depth) return "item menu";
    if (menu.held !== was.held) return menu.held === "Help" ? "help" : "help closed";
    if (menu.viewModel && menu.viewModel.selected.getTime() !== was.day) return "view";
    if (menu.filtering !== was.filtering) return "filter";
    if (menu.levels.length < was.depth) return "back";
    if (menu.inputFocused) return "input";
    if (was.input) return "body";
    if (menu.cursor.current !== was.cursor) return "cursor " + (menu.cursorItem?.key ?? "none");
    return handled ? "taken" : "nothing";
  }

  // As typing runs a key: the filter's keys while filtering, else the level's, then the cursor's.
  function pressOn(level, before, name) {
    menu.hide();
    menu.show();
    menu.push(level);
    if (before) before();
    ran = "";
    const was = { held: menu.held, day: menu.viewModel?.selected.getTime(), filtering: menu.filtering, depth: menu.levels.length, input: menu.inputFocused, cursor: menu.cursor.current };
    const did = outcome(menu.filtering ? menu.filterKey(name) : menu.handleName(name) || menu.cursorKey(name), was);
    menu.hide();
    return did;
  }

  ListFilter {
    id: probe
    size: 3
  }

  HeaderItem {
    id: barItem
    menu: menu
  }

  function tipOf(item) {
    return Array.from(item.children).find(child => child instanceof Tip)?.text;
  }

  // The clock squeezed in a crowded bar, which lays it out only in a window.
  FloatingWindow {
    implicitWidth: 300
    implicitHeight: 100

    HeaderItem {
      id: cutItem
      menu: menu
      width: 80
      item: ({ desc: "Calendar", status: "clock" })
    }
  }

  Suite {
    cases: [
      {
        name: "the filter's cursor stays on a row it shows when its item leaves the list",
        start: () => {
          probe.items = Array.from({ length: 10 }, (_, i) => ({ id: "i" + i, desc: "i" + i }));
          probe.move(8);
          probe.items = probe.items.filter(item => item.id !== "i8");
        },
        until: () => probe.rows.some(row => row.current && row.id === probe.item.id)
      },
      {
        name: "a tray app that only offers a menu opens it on its digit, never activated",
        until: () => {
          let activated = false;
          menu.hide();
          menu.show();
          menu.activate({ key: "1", desc: "Only menu", app: { onlyMenu: true, hasMenu: true, menu: null }, select: () => activated = true }, "1");
          const opened = menu.level?.kind === "menu" && !activated;
          menu.hide();
          return opened;
        }
      },
      {
        name: "the filter finds a label with accents typed without them",
        until: () => {
          probe.items = [{ id: "c", desc: "Café" }, { id: "t", desc: "Tea" }];
          probe.search("cafe");
          const found = probe.found.length === 1 && probe.item.id === "c";
          probe.search("CAFÉ");
          return found && probe.found.length === 1;
        }
      },
      {
        name: "the filter finds an item whose label the source gave as a number",
        until: () => {
          probe.items = Lists.items("numbered");
          probe.search("7");
          return probe.found.length === 1 && probe.item.id === 7;
        }
      },
      {
        name: "an app's stream lists as a device does: its name, its volume and meter, the wheel over it a step, its mute said beside it; with none playing, nothing to pick or change",
        until: () => {
          const node = { id: 7, properties: { "application.name": "Player" }, audio: { volume: 0.4, muted: false } };
          const item = Lists.stream(node, node);
          item.adjust(true);
          Audio.toggleMute(node);
          const after = Lists.stream(node, null);
          return item.desc === "Player" && item.active && item.detail === "40%" && item.meter === 0.4 && Math.abs(node.audio.volume - 0.45) < 1e-9
            && after.detail === Words.muted && !after.active && Lists.items("streams").length === 0 && Lists.empty("streams") === Words.emptyStreams
            && !Actions.builtin.streamVolume.available() && !Actions.builtin.streamMute.available();
        }
      },
      {
        name: "without its daemon, power profiles are offered nowhere: the action dims, the list is empty, the status shows nothing",
        until: () => !Power.profilesPresent && !Actions.builtin.powerProfile.available() && Lists.items("powerProfiles").length === 0 && Lists.empty("powerProfiles") === Words.noPowerProfiles
          && Statuses.builtin.powerProfile.glyph() === "" && Statuses.value(Statuses.builtin.powerProfile, Statuses.builtin.powerProfile.fields()).detail === ""
      },
      {
        name: "with no clock.format, the clock says the day and the time, never the year",
        until: () => !Clock.text.includes(String(Clock.date.getFullYear())) && Clock.text.includes(Clock.time(Clock.date))
      },
      {
        name: "without layouts to switch between, the keyboard layout status and action show nothing, so a bar hides them",
        until: () => KeyboardLayout.names.length < 2 && Statuses.of("keyboardLayout").glyph === "" && Statuses.of("keyboardLayout").text === "" && Actions.builtin.keyboardLayout.icon() === ""
      },
      {
        name: "without an adapter, the bluetooth status is not ready, so one appearing after startup is its first state, not a change to pop up",
        until: () => !Bluez.present && !Statuses.of("bluetooth").ready
      },
      {
        name: "a bar list's +N counts only what the bar leaves out and its picker shows, never a hidden item",
        until: () => Lists.items("hides").length === 2 && menu.barOf([{ desc: "H", list: "hides", limit: 1 }]).length === 1
      },
      {
        name: "pinned items keep their digits, dimmed while absent; the rest follow",
        until: () => JSON.stringify(menu.body.numbered("devices", [{ match: "b-*", label: "Bee" }, { match: "z-*", label: "Zed" }])
          .map(item => [item.key, item.desc, item.enabled !== false])) === '[["1","Bee",true],["2","Zed",false],["3","a-1",true]]'
      },
      {
        name: "keys show Emacs-style",
        until: () => MenuKeys.label(["Ctrl+Left", "Ctrl+Right"], true) === "C-←→" && MenuKeys.label("Return") === "RET" && MenuKeys.label("Alt+k") === "M-k"
      },
      {
        name: "keys are named as entries declare them: Shift picks the capital and names Shift+Return, a modifier alone has no name",
        until: () => JSON.stringify([
          { key: Qt.Key_A, modifiers: Qt.ShiftModifier, text: "A" },
          { key: Qt.Key_Left, modifiers: Qt.ControlModifier, text: "" },
          { key: Qt.Key_C, modifiers: Qt.ControlModifier | Qt.AltModifier, text: "\u0003" },
          { key: Qt.Key_Question, modifiers: Qt.ShiftModifier, text: "?" },
          { key: Qt.Key_Question, modifiers: Qt.ControlModifier | Qt.ShiftModifier, text: "\u001f" },
          { key: Qt.Key_Shift, modifiers: Qt.ShiftModifier, text: "" },
          { key: Qt.Key_Return, modifiers: Qt.ShiftModifier, text: "\r" },
          { key: Qt.Key_Enter, modifiers: Qt.NoModifier, text: "\r" }
        ].map(event => MenuKeys.name(event))) === '["A","Ctrl+Left","Ctrl+Alt+c","?","Ctrl+?","","Shift+Return","Return"]'
      },
      {
        name: "an action brings its icon and pairing, and dims with nothing to act on",
        until: () => {
          const [play, track, awake] = menu.body.itemsOf({ kind: "entry", entry: { submenu: [
            { key: "p", desc: "Play", action: "playPause" },
            { key: ["Left", "Right"], desc: "Track", action: "track", icon: "T" },
            { key: "k", desc: "Keep awake", action: "keepAwake" }
          ] } });
          return play.enabled === false && play.icon === Glyphs.playPause && track.paired && track.icon === "T" && awake.enabled && !awake.active;
        }
      },
      {
        name: "keep awake's enable turns it on whatever it was, where toggle would flip it",
        until: () => {
          KeepAwake.enable();
          KeepAwake.enable();
          const on = KeepAwake.enabled;
          KeepAwake.toggle();
          return on && !KeepAwake.enabled;
        }
      },
      {
        name: "/ filters the level's list in place, its rows held, and a digit runs its row as at rest",
        start: () => {
          menu.push({ kind: "entry", title: "Devices", entry: { list: "devices" } });
          menu.handleName("/");
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
        name: "Escape on an empty filter gives the level back at rest; a level opened to pick goes back to the input it came from, focused, or to the panel it opened over",
        until: () => {
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "devices" } });
          menu.body.startFilter();
          const filtered = menu.filtering;
          menu.stepBack();
          const rest = !menu.filtering && menu.levels.length === 1;
          menu.focusOn("input");
          menu.pickList("devices");
          const picking = menu.levels.length === 2 && menu.filtering && !menu.inputFocused;
          menu.stepBack();
          const refocused = menu.levels.length === 1 && menu.inputFocused;
          menu.hide();
          // The suite stands in for a plugin's panel the picker opens over.
          Panels.open(root);
          Picker.pick("devices");
          const fromPanel = menu.open && menu.levels.length === 1 && menu.filtering;
          menu.stepBack();
          const shownAgain = !menu.open && Panels.top === root;
          Panels.close();
          return filtered && rest && picking && refocused && fromPanel && shownAgain;
        }
      },
      {
        name: "Escape goes back a level and closes at the top, or at a level opened on its own; Backspace never goes back",
        until: () => {
          const escape = { key: Qt.Key_Escape, modifiers: Qt.NoModifier, text: "\u001b" };
          menu.hide();
          menu.show();
          menu.handleKey({ key: Qt.Key_A, modifiers: Qt.NoModifier, text: "a" });
          const backspace = !menu.handleKey({ key: Qt.Key_Backspace, modifiers: Qt.NoModifier, text: "\b" }) && menu.levels.length === 1;
          menu.handleKey(escape);
          const up = menu.open && menu.levels.length === 0;
          menu.handleKey(escape);
          const closed = !menu.open;
          menu.press("a");
          menu.handleKey(escape);
          const direct = !menu.open;
          menu.hide();
          return backspace && up && closed && direct;
        }
      },
      {
        name: "a list level's own entries sit on its bar and a menu's are its rows; / filters a list unless its level binds it, the legend saying so while it holds more than nine",
        until: () => {
          if (Plugins.get("many")?.items.length !== 10000) return false;
          menu.hide();
          menu.show();
          const top = menu.bodyActions.length > 0 && menu.barActions.length === 0 && !menu.slashFilters;
          menu.push({ kind: "entry", entry: { list: "many", submenu: [{ key: "m", desc: "Mute", cmd: "true" }] } });
          const content = menu.content && menu.barActions.length === 1 && menu.bodyActions.length === 0 && menu.barShown;
          const legend = menu.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join() === "/ 1-9 of 10000";
          const listed = menu.help.some(key => key.key === "/");
          menu.handleKey({ key: Qt.Key_Slash, modifiers: Qt.NoModifier, text: "/" });
          const filtering = menu.filtering && menu.barActions.length === 0;
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "many", submenu: [{ key: "/", desc: "Slash", cmd: "true" }] } });
          const bound = !menu.slashFilters && menu.legend.length === 0;
          menu.push({ kind: "entry", entry: { submenu: [{ key: "m", desc: "Mute", cmd: "true" }] } });
          const bare = !menu.content && !menu.barShown;
          menu.hide();
          return top && content && legend && listed && filtering && bound && bare;
        }
      },
      {
        name: "an entry's action may be one of the plugin its level lists, its icon and value as a built-in one's; a name the plugin lacks dims",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          let ran = 0;
          plugin.actions = { flip: { icon: () => Glyphs.search, detail: () => "on", available: () => true, run: () => ran++ } };
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "devices", submenu: [{ key: "f", desc: "Flip", action: "flip" }, { key: "g", desc: "Gone", action: "gone" }] } });
          const [flip, gone] = menu.body.actions;
          menu.handleName("f");
          menu.hide();
          plugin.actions = {};
          return flip.icon === Glyphs.search && flip.detail === "on" && flip.enabled && !gone.enabled && ran === 1;
        }
      },
      {
        name: "the wheel steps a pair on any keys, up as its second",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          const steps = [];
          plugin.actions = { step: { pair: true, icon: () => "", available: () => true, run: up => steps.push(up) } };
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "devices", submenu: [{ key: ["Left", "Right"], desc: "Step", action: "step" }] } });
          menu.act(menu.body.actions[0], true);
          menu.act(menu.body.actions[0], false);
          menu.hide();
          plugin.actions = {};
          return JSON.stringify(steps) === "[true,false]";
        }
      },
      {
        name: "a list of 10000 opens and filters, printing how long each took",
        until: () => {
          if (Plugins.get("many")?.items.length !== 10000) return false;
          menu.hide();
          let start = Date.now();
          menu.pickList("many");
          const opened = menu.rows.length;
          const open = Date.now() - start;
          start = Date.now();
          menu.filter.search("item 99");
          const filtered = menu.rows.length;
          const filter = Date.now() - start;
          start = Date.now();
          for (let i = 0; i < 100; i++) menu.filter.move(1);
          const move = (Date.now() - start) / 100;
          console.info("# 10000 items: open " + open + " ms, filter " + filter + " ms, move " + move + " ms");
          return opened === 9 && filtered === 9;
        }
      },
      {
        name: "the filter keeps the rows whose label holds every word, case aside; a digit never types",
        start: () => menu.filter.search("99 ITEM"),
        until: () => menu.filter.found.length === 280 && menu.rows[0].desc === "Item 99" && menu.filter.count === "1-9 of 280" && menu.filterKey("5") && menu.filter.query === "99 ITEM"
      },
      {
        name: "nothing matching says so, in the rows' place",
        start: () => menu.filter.search("plumb"),
        until: () => menu.rows.length === 0 && menu.emptyText === "Nothing matches plumb"
      },
      {
        name: "while filtering, the digits label the rows shown and move with the cursor, its row lit",
        start: () => {
          menu.filter.search("");
          menu.filter.move(10);
        },
        until: () => menu.filter.index === 10 && menu.filter.first === 2 && menu.rows[0].desc === "Item 2" && menu.rows[8].key === "9" && menu.rows[8].desc === "Item 10" && menu.rows[8].current
      },
      {
        name: "while filtering, PgDn and PgUp move the cursor a page of rows",
        until: () => {
          menu.filter.search("");
          const named = MenuKeys.name({ key: Qt.Key_PageDown, modifiers: Qt.NoModifier, text: "" }) === "Page_Down";
          const down = menu.filterKey("Page_Down") && menu.filter.index === 9 && menu.rows[8].current;
          const up = menu.filterKey("Page_Up") && menu.filter.index === 0 && menu.rows[0].current;
          return named && down && up;
        }
      },
      {
        name: "the cursor stays on its item as the list changes",
        start: () => {
          Quickshell.execDetached(["sh", "-c", `echo '{"items": [{"id": "a"}, {"id": "b"}, {"id": "c"}]}' > "$XDG_RUNTIME_DIR/ordered"`]);
          menu.hide();
          menu.pickList("ordered");
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
          menu.pickList("acting");
        },
        until: () => {
          if (root.acted === null && menu.rows.length === 1) {
            const legend = menu.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join(", ");
            const counted = menu.filter.count;
            menu.filterKey("Alt+1");
            const own = menu.level.kind === "actions" && menu.items[0].key === "d" && menu.barSlots.left[0].desc === "A";
            menu.handleName("d");
            root.acted = legend === "1 pick, ↑ move, RET open, M-RET menu" && counted === "1 of 1" && own && menu.level.picking && menu.filtering;
          }
          return root.acted === true && Plugins.get("picked")?.text === "a d";
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
        name: "at rest the arrows move a cursor from the item in use and stop at the last row shown, digits staying on their items; the legend names Return, ? the arrows",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = plugin.items;
          plugin.items = Array.from({ length: 12 }, (_, i) => ({ id: "i" + i, verb: "open", active: i === 2, actions: [{ key: "d" }] }));
          menu.hide();
          menu.show();
          menu.push(root.bareLevel);
          const listed = menu.help.some(key => key.desc === Words.helpMove);
          menu.cursorKey("Down");
          const moved = menu.cursorItem?.id === "i3" && menu.rows[3].current && menu.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join(", ") === "/ 1-9 of 12, RET open, M-RET menu";
          for (let i = 0; i < 20; i++) menu.cursorKey("Down");
          const stopped = menu.cursorItem?.key === "9" && menu.rows[0].id === "i0" && menu.rows[0].key === "1";
          menu.push(root.downLevel);
          const bound = !menu.help.some(key => key.desc === Words.helpMove);
          menu.hide();
          plugin.items = was;
          return listed && moved && stopped && bound;
        }
      },
      {
        name: "a key path never moves the cursor",
        until: () => {
          menu.hide();
          const ran = menu.press("t Down") || menu.press("Down");
          const none = !menu.cursorItem;
          menu.hide();
          return !ran && none;
        }
      },
      {
        name: "at the top the arrows move over the entries as laid out, Return opens one as its letter would, and Escape back keeps its row",
        until: () => {
          menu.hide();
          menu.show();
          const moved = menu.cursorKey("Down") && menu.cursor.current === "a" && menu.cursorKey("Right") && menu.cursor.current === "t"
            && menu.cursorKey("Down") && menu.cursor.current === "t" && menu.bodyActions[1].current && menu.cursorKey("Left");
          const opened = menu.cursorKey("Return") && menu.level?.entry?.desc === "Audio" && !menu.cursorItem;
          menu.stepBack();
          const kept = menu.level === null && menu.cursor.current === "a";
          menu.hide();
          return moved && opened && kept;
        }
      },
      {
        name: "a level without a bar grows none as its cursor shows, where one with a bar names Return, and the top level's bar holds still",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = plugin.items;
          plugin.items = [{ id: "a" }, { id: "b" }];
          menu.hide();
          menu.show();
          menu.push(root.bareLevel);
          const bare = !menu.barShown && menu.cursorKey("Down") && !!menu.cursorItem && !menu.barShown;
          menu.push(root.keyedLevel);
          const named = menu.cursorKey("Down") && menu.barShown && menu.legend.some(key => key.key === "Return");
          menu.hide();
          menu.show();
          const before = menu.legend.length;
          const still = menu.cursorKey("Down") && !!menu.cursorItem && menu.legend.length === before;
          menu.hide();
          plugin.items = was;
          return bare && named && still;
        }
      },
      {
        name: "leaving the filter, the cursor stays on the row its arrows moved to, and shows none where they did not move",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = plugin.items;
          plugin.items = Array.from({ length: 12 }, (_, i) => ({ id: "i" + i }));
          menu.hide();
          menu.show();
          menu.push(root.bareLevel);
          menu.body.startFilter();
          menu.filterKey("Down");
          menu.filterKey("Down");
          menu.stepBack();
          const carried = !menu.filtering && menu.cursorItem?.id === "i2" && menu.rows[2].current;
          menu.body.startFilter();
          menu.filter.search("i1");
          menu.stepBack();
          const none = !menu.filtering && !menu.cursorItem;
          menu.hide();
          plugin.items = was;
          return carried && none;
        }
      },
      {
        name: "Ctrl held lists the bar's keys, each named, a pair as one",
        start: () => menu.hold("Ctrl"),
        until: () => JSON.stringify(menu.hints.map(hint => [MenuKeys.label(hint.key, hint.paired), hint.desc])) === '[["C-x","X"],["C-↓↑","Volume"],["C-k","Clicked"],["C-1","a-1"],["C-0","+1"]]'
      },
      {
        name: "a built-in status is shaped by its own format, an entry's over it, and music by its value",
        until: () => {
          const value = (name, fields, format) => JSON.stringify(Statuses.value(Statuses.builtin[name], fields, format));
          return value("sink", { device: "Speakers", volume: "40%" }) === JSON.stringify({ text: "Speakers", detail: "40%" })
            && value("bluetooth", { state: "off" }) === JSON.stringify({ text: "", detail: "off" })
            && value("keepAwake", {}) === JSON.stringify({ text: "", detail: "" })
            && value("sink", { device: "Speakers", volume: "40%" }, "{volume}") === JSON.stringify({ text: "40%", detail: "" })
            && Statuses.value(Statuses.builtin.music, { song: "Song" }).text === "Song";
        }
      },
      {
        name: "a status says its state in lowercase but for a name",
        until: () => Statuses.value(Statuses.builtin.music, Statuses.builtin.music.fields()).text === "no song playing"
          && [Words.disconnected, Words.noInternet, Words.noDevice].every(word => word === word.toLowerCase())
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
          menu.hold("");
          menu.handleKey({ key: Qt.Key_Question, modifiers: Qt.ShiftModifier, text: "?" });
        },
        until: () => {
          if (MenuKeys.label(menu.hints[menu.hints.length - 1]?.key ?? "") !== "ESC") return false;
          menu.handleKey({ key: Qt.Key_X, modifiers: Qt.NoModifier, text: "x" });
          return menu.held === "";
        }
      },
      {
        name: "? lists only keys that act: a hold while it lists something, the arrows each pair a level leaves free, RET on a grid and S-RET by a capital, M-1 while an item has its own menu; the top level's bar shows ?",
        until: () => {
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "acting" } });
          if (menu.rows.length !== 1) return false;
          const listed = level => {
            menu.levels = level ? [level] : [];
            return menu.help.map(key => key.key).join();
          };
          const hinted = () => menu.legend.some(key => key.key === "?");
          return listed(null).startsWith("Ctrl+,") && !listed(null).includes("Super+") && hinted() && listed({ kind: "entry", entry: { list: "acting" } }) === "Up,Down,Alt+1,/,Escape"
            && !hinted() && listed({ kind: "entry", entry: { list: "devices" } }) === "Up,Down,/,Escape"
            && listed(null).includes(",Up,Down,Left,Right,Return,") && listed(root.gridLevel) === "Up,Down,Left,Right,Return,Shift+Return,Escape"
            && listed({ kind: "entry", entry: { submenu: [{ key: ["Left", "Right"], desc: "Step", cmd: ["true", "true"] }] } }) === "Up,Down,Return,Escape";
        }
      },
      {
        name: "menu.layout lists the islands top to bottom, each once: [ body input bar ] puts the input between the body and the bar",
        until: () => {
          const before = menu.layout.join();
          Config.menu.layout = ["body", "input", "input", "bar"];
          const after = menu.layout.join();
          Config.menu.layout = ["input", "body", "bar"];
          return before === "input,body,bar" && after === "body,input,bar";
        }
      },
      {
        name: "a layout without an input shows no level's input and filters nothing",
        until: () => {
          menu.hide();
          menu.levels = [root.keyedLevel];
          const before = menu.input.input !== null && menu.slashFilters;
          Config.menu.layout = ["body", "bar"];
          const without = menu.input.input === null && !menu.slashFilters && !menu.handleName("Tab") && !menu.inputFocused;
          Config.menu.layout = ["input", "body", "bar"];
          menu.levels = [];
          return before && without;
        }
      },
      {
        name: "menu.keysHint off leaves ? off the top level's bar, and ? still lists the keys",
        until: () => {
          menu.hide();
          Config.menu.keysHint = false;
          menu.levels = [];
          const hidden = !menu.legend.some(key => key.key === "?") && menu.handleName("?") && menu.held === "Help";
          menu.handleName("?");
          Config.menu.keysHint = true;
          return hidden && menu.held === "" && menu.legend.some(key => key.key === "?");
        }
      },
      {
        name: "on a calendar level, ? lists the arrows its legend leaves to the grid, and the year's keys",
        until: () => {
          menu.hide();
          menu.push(root.calendarLevel);
          const labels = keys => keys.map(key => MenuKeys.label(key.key, true));
          const listed = labels(menu.help).join().startsWith("←→,↑↓,C-↑↓,") && !labels(menu.legend).includes("←→") && !labels(menu.legend).includes("C-↑↓");
          menu.hide();
          return listed;
        }
      },
      {
        name: "a level's legend shows the keys of its ? list it names in its bar, after its own, in its order and once; one ? lists not now shows nowhere",
        until: () => {
          menu.hide();
          const shown = () => menu.legend.map(key => MenuKeys.label(key.key, true) + " " + (key.what ?? key.desc));
          menu.push(root.calendarLevel);
          const own = shown();
          menu.levels = [];
          menu.push({ kind: "entry", entry: Object.assign({ legend: ["Ctrl+Down", "Escape", "Ctrl+Up", "Ctrl+"] }, root.calendarLevel.entry) });
          const chosen = shown();
          menu.hide();
          return chosen.join() === own.concat(["C-↑↓ Move a year", "ESC Clear, else back"]).join();
        }
      },
      {
        name: "an input's key gives it the keys, its text reaches its command, and its after runs, given nothing, once the command succeeds",
        start: () => {
          menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Add", cmd: "printf '%s\\n' > \"$XDG_RUNTIME_DIR/picked\"", after: "echo \"done $#\" > \"$XDG_RUNTIME_DIR/followed\"" } } });
          menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          menu.input.submit("  typed  ", false);
        },
        until: () => menu.inputFocused && Plugins.get("picked")?.text === "typed" && Plugins.get("followed")?.text === "done 0"
      },
      {
        name: "an input naming a plugin gives it its text, its context beside it and the text shown as typed, the level's legend staying as it was; in the background the menu closes",
        start: () => {
          menu.levels = [];
          menu.push({ kind: "entry", entry: { view: "calendar", input: { desc: "Add an event", plugin: "agent", context: "Calendar" } } });
          menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          root.typingLegend = menu.legend.map(key => MenuKeys.label(key.key));
          menu.input.submit("typed", true);
        },
        until: () => root.typingLegend.length > 0 && !root.typingLegend.includes("ESC") && menu.levels.length === 0 && Plugins.get("agent")?.exchanges[0]?.prompt === "typed" && Plugins.get("agent")?.exchanges[0]?.reply.endsWith("[Calendar]")
      },
      {
        name: "an input whose plugin did not load takes nothing, so the menu stays and the input keeps its text",
        until: () => {
          menu.levels = [];
          menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Add", plugin: "gone" } } });
          return menu.input.submit("kept", true) === false && menu.levels.length === 1;
        }
      },
      {
        name: "an input on a list whose plugin takes no text keeps its text, and the menu stays",
        until: () => {
          menu.levels = [];
          menu.push({ kind: "entry", entry: { list: "devices", input: { desc: "Add" } } });
          return Plugins.get("devices") !== null && menu.input.submit("kept", true) === false && menu.levels.length === 1;
        }
      },
      {
        name: "in the body Tab moves to the input, and Shift+Tab is left to Qt",
        until: () => {
          menu.levels = [{ kind: "entry", entry: { submenu: [], input: { desc: "Add", cmd: "true" } } }];
          menu.focusOn("body");
          const backtab = menu.handleKey({ key: Qt.Key_Backtab, modifiers: Qt.ShiftModifier, text: "" });
          const tab = menu.handleKey({ key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" });
          return !backtab && tab && menu.inputFocused;
        }
      },
      {
        name: "every message of a visit carries the input's context, each shown as typed; expanding holds the visit, and stepping back returns to the level with the input focused",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent || agent.busy) return false;
          switch (root.visitStep) {
          case 0:
            menu.show();
            menu.levels = [{ kind: "entry", entry: { submenu: [], input: { desc: "Add", plugin: "agent", context: "Tasks" } } }];
            root.visitStep = menu.input.submit("one", false) ? 1 : -1;
            return false;
          case 1:
            root.visitStep = agent.turn?.question === "one" && agent.turn?.text.endsWith("[Tasks]") && menu.input.submit("two", false) ? 2 : -1;
            return false;
          case 2:
            if (agent.turn?.question !== "two" || !agent.turn?.text.endsWith("[Tasks]")) return false;
            const token = menu.input.visit;
            menu.input.expand();
            // Under the panel, the menu keeps its level and the visit.
            const held = agent.shown && !menu.open && menu.inStack && menu.input.visit === token;
            Panels.back();
            root.visitStep = held && menu.open && menu.levels.length === 1 && menu.inputFocused && menu.input.visit === token && agent.turn?.question === "two" ? 3 : -1;
            return false;
          }
          menu.hide();
          return root.visitStep === 3;
        }
      },
      {
        name: "each input keeps its own unsent text",
        until: () => {
          const first = { kind: "entry", entry: { submenu: [], input: { desc: "First", cmd: "true" } } };
          menu.levels = [first];
          menu.input.keepDraft("one");
          menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Second", cmd: "true" } } });
          const second = menu.input.draft;
          menu.levels = [first];
          return second === "" && menu.input.draft === "one";
        }
      },
      {
        name: "an input keeps its unsent text as its label changes",
        until: () => {
          menu.levels = [{ kind: "entry", entry: { key: "d", submenu: [], input: { desc: "Before", cmd: "true" } } }];
          menu.input.keepDraft("kept");
          menu.levels = [{ kind: "entry", entry: { key: "d", submenu: [], input: { desc: "After", cmd: "true" } } }];
          return menu.input.draft === "kept";
        }
      },
      {
        name: "C-r in an input to a plugin that recalls lists its conversations on a level over it, filtering, and ? names it",
        until: () => {
          menu.hide();
          menu.levels = [{ kind: "entry", entry: { submenu: [], input: { desc: "Ask", plugin: "agent" } } }];
          const named = menu.help.some(key => key.key === "Ctrl+r");
          return named && menu.input.recall() && menu.levels.length === 2 && menu.level.picking && menu.level.entry.list === "agent" && menu.filtering;
        }
      },
      {
        name: "a level lays its actions out in its own columns, else menu.columns",
        until: () => {
          menu.hide();
          menu.push({ kind: "entry", entry: { submenu: [], columns: 1 } });
          const own = menu.columns === 1;
          menu.hide();
          return own && menu.columns === Config.menu.columns;
        }
      },
      {
        name: "a key path runs from the top level as typing it would, and the key map lists every path",
        start: () => {
          menu.hide();
          root.pathRan = menu.press("Ctrl+x") && !menu.press("a nope");
        },
        until: () => {
          const map = menu.keyMap();
          return root.pathRan && map.includes("- `Ctrl+x` X") && map.includes("- `Ctrl+Down` `Ctrl+Up` Volume") && map.includes("  - `a Ctrl+v` Vee") && Plugins.get("picked")?.text === "bar";
        }
      },
      {
        name: "a key path ends at a key that closes the menu, leaving no level for its next opening",
        until: () => {
          menu.hide();
          return !menu.press("a Ctrl+v a") && !menu.open && menu.levels.length === 0;
        }
      },
      {
        name: "a key path ending on an action closes the menu it opened, unless the entry keeps it open or the menu was open before",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          let ran = 0;
          plugin.actions = { flip: { icon: () => Glyphs.search, available: () => true, run: () => ran++ } };
          menu.hide();
          menu.press("t f");
          const closed = !menu.open;
          menu.press("t k");
          const kept = menu.open && menu.levels.length === 1;
          menu.press("t f");
          const stayed = menu.open && menu.levels.length === 1;
          menu.hide();
          plugin.actions = {};
          return ran === 3 && closed && kept && stayed;
        }
      },
      {
        name: "a key path ending on a list pick closes the menu it opened",
        start: () => {
          menu.hide();
          root.pathRan = menu.press("t 2");
          root.pathClosed = !menu.open;
        },
        until: () => root.pathRan && root.pathClosed && Plugins.get("picked")?.text === "b-2"
      },
      {
        name: "a held pair steps on the level it was pressed on, never into the one it opened, and a held letter or digit acts once, as Return on the cursor's row does",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          let ran = 0;
          let steps = 0;
          plugin.actions = { flip: { icon: () => Glyphs.search, available: () => true, run: () => ran++ }, step: { pair: true, icon: () => "", available: () => true, run: () => steps++ } };
          const key = (key, text, repeat) => ({ key, modifiers: Qt.NoModifier, text, isAutoRepeat: repeat });
          menu.hide();
          menu.show();
          menu.handleKey(key(Qt.Key_A, "a", false));
          menu.handleKey(key(Qt.Key_A, "a", true));
          const held = menu.levels.length === 1;
          menu.handleKey(key(Qt.Key_A, "a", false));
          const pressed = menu.levels.length === 2;
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "devices", submenu: [{ key: "f", desc: "Flip", action: "flip" }, { key: "9", desc: "Nine", action: "flip" },
            { key: ["Left", "Right"], desc: "Step", action: "step" }] } });
          for (const repeat of [false, true, true]) {
            menu.handleKey(key(Qt.Key_F, "f", repeat));
            menu.handleKey(key(Qt.Key_9, "9", repeat));
            menu.handleKey(key(Qt.Key_Right, "", repeat));
          }
          menu.hide();
          plugin.actions = {};
          // Held, Return acts once on the cursor's row, S-RET on a capital's too.
          const awake = KeepAwake.enabled;
          menu.push({ kind: "entry", entry: { submenu: [{ key: "I", desc: "Awake", action: "keepAwake" }] } });
          menu.cursorKey("Down");
          for (const repeat of [false, true]) menu.handleKey({ key: Qt.Key_Return, modifiers: Qt.ShiftModifier, text: "\r", isAutoRepeat: repeat });
          const once = KeepAwake.enabled !== awake;
          if (KeepAwake.enabled !== awake) KeepAwake.toggle();
          menu.hide();
          return held && pressed && ran === 2 && steps === 3 && once;
        }
      },
      {
        name: "an entry showing a plugin, without a command, activates it as a click does",
        start: () => {
          menu.hide();
          menu.press("Ctrl+k");
        },
        until: () => Plugins.get("picked")?.text === "clicked"
      },
      {
        name: "toggleEntry on a bar list's digit runs its item",
        start: () => {
          menu.hide();
          menu.toggleEntry("1");
        },
        until: () => Plugins.get("picked")?.text === "a-1"
      },
      {
        name: "a bar entry showing only a plugin's status takes a click, which activates the plugin",
        start: () => {
          menu.hide();
          barItem.item = menu.barSlots.left.find(item => item.key === "k");
          if (barItem.enabled) barItem.activated();
        },
        until: () => barItem.enabled && Plugins.get("picked")?.text === "clicked"
      },
      {
        name: "a bar status cut to fit tips its value whole",
        until: () => root.tipOf(cutItem) === Clock.text
      },
      {
        name: "a bar status shown whole has no tip",
        start: () => cutItem.width = cutItem.implicitWidth,
        until: () => root.tipOf(cutItem) === ""
      },
      {
        name: "the keyed plugin lists one item with a menu of its own, and runs the actions the table's rows name",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          plugin.items = [{ id: "one", closes: true, actions: [{ key: "d" }] }];
          plugin.actions = { row: { icon: () => "", available: () => true, run: () => root.ran = "row" }, bar: { icon: () => "", available: () => true, run: () => root.ran = "bar" } };
          return Lists.items("keyed").length === 1;
        }
      }
    ].concat(root.keyed.map(([what, level, before, name, expected]) => ({
      name: what,
      timeout: 0,
      until: () => {
        const did = root.pressOn(level, before, name);
        if (did !== expected) console.info("# " + name + " did " + did);
        return did === expected;
      }
    })))
  }

  MenuModel {
    id: menu
  }
}
