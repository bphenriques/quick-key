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
  // The entries config.json sets, while a case pins others.
  property var entries: null

  // A top level whose list on t, Tasks, is pinned between the input and the body, showing `limit` of its items.
  function pinning(limit, more = []) {
    menu.hide();
    if (!root.entries) root.entries = Config.menu.entries;
    Config.menu.entries = [{ key: "t", desc: "Tasks", list: "devices", limit, input: { desc: "Add a task...", cmd: "true" }, submenu: [{ key: "f", desc: "Flip", action: "flip" }] },
      { key: "a", desc: "Audio", submenu: [] }].concat(more);
    Config.menu.layout = ["input", { level: "t" }, "body", "bar"].concat(more.map(entry => ({ level: entry.key })));
    menu.show();
    return menu.modelOf("t");
  }

  // Tasks pinned on t, Audio opening in the body, and Calendar, on c and on Tasks' o, with a layout of its own pinning its Events on e.
  function routing() {
    const calendar = { key: "c", desc: "Calendar", layout: ["input", { level: "e" }, "body", "bar"], submenu: [{ key: "e", desc: "Events", list: "devices", limit: 2,
      input: { desc: "Add an event...", cmd: "true" }, submenu: [{ key: "g", desc: "Go", cmd: "true" }] }, { key: "d", desc: "Day", submenu: [] }] };
    root.pinning(2, []);
    menu.hide();
    Config.menu.entries = [Object.assign({}, Config.menu.entries[0], { submenu: [Object.assign({}, calendar, { key: "o" })] }), Config.menu.entries[1], calendar];
    menu.show();
    return menu.modelOf("t");
  }

  function unpinning() {
    menu.hide();
    Config.menu.layout = ["input", "body", "bar"];
    Config.menu.entries = root.entries;
    return true;
  }

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
    if (menu.body.viewModel && menu.body.viewModel.selected.getTime() !== was.day) return "view";
    if (menu.body.filtering !== was.filtering) return "filter";
    if (menu.levels.length < was.depth) return "back";
    if (menu.inputFocused) return "input";
    if (was.input) return "body";
    if (menu.body.cursor.current !== was.cursor) return "cursor " + (menu.body.cursorItem?.key ?? "none");
    return handled ? "taken" : "nothing";
  }

  // As typing runs a key: the filter's keys while filtering, else the level's, then the cursor's.
  function pressOn(level, before, name) {
    menu.hide();
    menu.show();
    menu.push(level);
    if (before) before();
    ran = "";
    const was = { held: menu.held, day: menu.body.viewModel?.selected.getTime(), filtering: menu.body.filtering, depth: menu.levels.length, input: menu.inputFocused, cursor: menu.body.cursor.current };
    const did = outcome(menu.body.filtering ? menu.filterKey(name) : menu.handleName(name) || menu.cursorKey(name), was);
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

    MenuRow {
      id: pinRow
      y: 70
      menu: menu
      level: menu.body
    }

    MenuHeader {
      id: header
      y: 40
      menu: menu
      room: 300
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
          if (!root.pressed && menu.body.filtering && menu.body.filterSlots === 2 && menu.body.rows.length === 2) root.pressed = menu.filterKey("2");
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
          if (root.pressed && menu.level?.picking && menu.body.filtering && menu.body.filterSlots === 9 && menu.body.rows.length === 2) root.pressed = !menu.filterKey("2");
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
          const filtered = menu.body.filtering;
          menu.stepBack();
          const rest = !menu.body.filtering && menu.levels.length === 1;
          menu.focusOn("input");
          menu.pickList("devices");
          const picking = menu.levels.length === 2 && menu.body.filtering && !menu.inputFocused;
          menu.stepBack();
          const refocused = menu.levels.length === 1 && menu.inputFocused;
          menu.hide();
          // The suite stands in for a plugin's panel the picker opens over.
          Panels.open(root);
          Picker.pick("devices");
          const fromPanel = menu.open && menu.levels.length === 1 && menu.body.filtering;
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
          const top = menu.body.bodyActions.length > 0 && menu.body.barActions.length === 0 && !menu.body.slashFilters;
          menu.push({ kind: "entry", entry: { list: "many", submenu: [{ key: "m", desc: "Mute", cmd: "true" }] } });
          const content = menu.body.content && menu.body.barActions.length === 1 && menu.body.bodyActions.length === 0 && menu.barShown;
          const legend = menu.body.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join() === "/ 1-9 of 10000";
          const listed = menu.help.some(key => key.key === "/");
          menu.handleKey({ key: Qt.Key_Slash, modifiers: Qt.NoModifier, text: "/" });
          const filtering = menu.body.filtering && menu.body.barActions.length === 0;
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "many", submenu: [{ key: "/", desc: "Slash", cmd: "true" }] } });
          const bound = !menu.body.slashFilters && menu.body.legend.length === 0;
          menu.push({ kind: "entry", entry: { submenu: [{ key: "m", desc: "Mute", cmd: "true" }] } });
          const bare = !menu.body.content && !menu.barShown;
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
          const opened = menu.body.rows.length;
          const open = Date.now() - start;
          start = Date.now();
          menu.body.filter.search("item 99");
          const filtered = menu.body.rows.length;
          const filter = Date.now() - start;
          start = Date.now();
          for (let i = 0; i < 100; i++) menu.body.filter.move(1);
          const move = (Date.now() - start) / 100;
          console.info("# 10000 items: open " + open + " ms, filter " + filter + " ms, move " + move + " ms");
          return opened === 9 && filtered === 9;
        }
      },
      {
        name: "the filter keeps the rows whose label holds every word, case aside; a digit never types",
        start: () => menu.body.filter.search("99 ITEM"),
        until: () => menu.body.filter.found.length === 280 && menu.body.rows[0].desc === "Item 99" && menu.body.filter.count === "1-9 of 280" && menu.filterKey("5") && menu.body.filter.query === "99 ITEM"
      },
      {
        name: "nothing matching says so, in the rows' place",
        start: () => menu.body.filter.search("plumb"),
        until: () => menu.body.rows.length === 0 && menu.body.emptyText === "Nothing matches plumb"
      },
      {
        name: "while filtering, the digits label the rows shown and move with the cursor, its row lit",
        start: () => {
          menu.body.filter.search("");
          menu.body.filter.move(10);
        },
        until: () => menu.body.filter.index === 10 && menu.body.filter.first === 2 && menu.body.rows[0].desc === "Item 2" && menu.body.rows[8].key === "9" && menu.body.rows[8].desc === "Item 10" && menu.body.rows[8].current
      },
      {
        name: "while filtering, PgDn and PgUp move the cursor a page of rows",
        until: () => {
          menu.body.filter.search("");
          const named = MenuKeys.name({ key: Qt.Key_PageDown, modifiers: Qt.NoModifier, text: "" }) === "Page_Down";
          const down = menu.filterKey("Page_Down") && menu.body.filter.index === 9 && menu.body.rows[8].current;
          const up = menu.filterKey("Page_Up") && menu.body.filter.index === 0 && menu.body.rows[0].current;
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
          if (root.orderStep === 0 && menu.body.filter.items.length === 3) {
            menu.body.filter.move(1);
            root.orderStep = 1;
            Quickshell.execDetached(["sh", "-c", `echo '{"items": [{"id": "z"}, {"id": "a"}, {"id": "b"}, {"id": "c"}]}' > "$XDG_RUNTIME_DIR/ordered"`]);
          }
          return root.orderStep === 1 && menu.body.filter.items.length === 4 && menu.body.filter.item?.id === "b" && menu.body.filter.index === 2;
        }
      },
      {
        name: "while filtering, an item's verb names Return, and Alt opens its own menu, whose keys run its plugin's actions and step back",
        start: () => {
          menu.hide();
          menu.pickList("acting");
        },
        until: () => {
          if (root.acted === null && menu.body.rows.length === 1) {
            const legend = menu.body.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join(", ");
            const counted = menu.body.filter.count;
            menu.filterKey("Alt+1");
            const own = menu.level.kind === "actions" && menu.body.items[0].key === "d" && menu.barSlots.left[0].desc === "A";
            menu.handleName("d");
            root.acted = legend === "1 pick, ↑ move, RET open, M-RET menu" && counted === "1 of 1" && own && menu.level.picking && menu.body.filtering;
          }
          return root.acted === true && Plugins.get("picked")?.text === "a d";
        }
      },
      {
        name: "at rest, Alt with an item's digit opens its own menu too",
        until: () => {
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "acting" } });
          if (menu.body.rows.length !== 1) return false;
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
          const moved = menu.body.cursorItem?.id === "i3" && menu.body.rows[3].current && menu.body.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join(", ") === "/ 1-9 of 12, RET open, M-RET menu";
          for (let i = 0; i < 20; i++) menu.cursorKey("Down");
          const stopped = menu.body.cursorItem?.key === "9" && menu.body.rows[0].id === "i0" && menu.body.rows[0].key === "1";
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
          const none = !menu.body.cursorItem;
          menu.hide();
          return !ran && none;
        }
      },
      {
        name: "at the top the arrows move over the entries as laid out, Return opens one as its letter would, and Escape back keeps its row",
        until: () => {
          menu.hide();
          menu.show();
          const moved = menu.cursorKey("Down") && menu.body.cursor.current === "a" && menu.cursorKey("Right") && menu.body.cursor.current === "t"
            && menu.cursorKey("Down") && menu.body.cursor.current === "t" && menu.body.bodyActions[1].current && menu.cursorKey("Left");
          const opened = menu.cursorKey("Return") && menu.level?.entry?.desc === "Audio" && !menu.body.cursorItem;
          menu.stepBack();
          const kept = menu.level === null && menu.body.cursor.current === "a";
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
          const bare = !menu.barShown && menu.cursorKey("Down") && !!menu.body.cursorItem && !menu.barShown;
          menu.push(root.keyedLevel);
          const named = menu.cursorKey("Down") && menu.barShown && menu.body.legend.some(key => key.key === "Return");
          menu.hide();
          menu.show();
          const before = menu.body.legend.length;
          const still = menu.cursorKey("Down") && !!menu.body.cursorItem && menu.body.legend.length === before;
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
          const carried = !menu.body.filtering && menu.body.cursorItem?.id === "i2" && menu.body.rows[2].current;
          menu.body.startFilter();
          menu.body.filter.search("i1");
          menu.stepBack();
          const none = !menu.body.filtering && !menu.body.cursorItem;
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
        until: () => menu.body.emptyText === "Nothing found"
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
          if (menu.body.rows.length !== 1) return false;
          const listed = level => {
            menu.levels = level ? [level] : [];
            return menu.help.map(key => key.key).join();
          };
          const hinted = () => menu.body.legend.some(key => key.key === "?");
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
          const before = menu.input.input !== null && menu.body.slashFilters;
          Config.menu.layout = ["body", "bar"];
          const without = menu.input.input === null && !menu.body.slashFilters && !menu.handleName("Tab") && !menu.inputFocused;
          Config.menu.layout = ["input", "body", "bar"];
          menu.levels = [];
          return before && without;
        }
      },
      {
        name: "a picker on a layout without an input still takes its arrows, as the filter's",
        until: () => {
          if (Plugins.get("many")?.items.length !== 10000) return false;
          menu.hide();
          Config.menu.layout = ["body", "bar"];
          menu.pickList("many");
          const was = menu.body.filter.current;
          const taken = menu.handleKey({ key: Qt.Key_Down, modifiers: Qt.NoModifier, text: "" });
          const moved = menu.body.filtering && menu.body.filter.current !== was;
          menu.hide();
          Config.menu.layout = ["input", "body", "bar"];
          return taken && moved;
        }
      },
      {
        name: "menu.keysHint off leaves ? off the top level's bar, and ? still lists the keys",
        until: () => {
          menu.hide();
          Config.menu.keysHint = false;
          menu.levels = [];
          const hidden = !menu.body.legend.some(key => key.key === "?") && menu.handleName("?") && menu.held === "Help";
          menu.handleName("?");
          Config.menu.keysHint = true;
          return hidden && menu.held === "" && menu.body.legend.some(key => key.key === "?");
        }
      },
      {
        name: "on a calendar level, ? lists the arrows its legend leaves to the grid, and the year's keys",
        until: () => {
          menu.hide();
          menu.push(root.calendarLevel);
          const labels = keys => keys.map(key => MenuKeys.label(key.key, true));
          const listed = labels(menu.help).join().startsWith("←→,↑↓,C-↑↓,") && !labels(menu.body.legend).includes("←→") && !labels(menu.body.legend).includes("C-↑↓");
          menu.hide();
          return listed;
        }
      },
      {
        name: "a level's legend shows the keys of its ? list it names in its bar, after its own, in its order and once; one ? lists not now shows nowhere",
        until: () => {
          menu.hide();
          const shown = () => menu.body.legend.map(key => MenuKeys.label(key.key, true) + " " + (key.what ?? key.desc));
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
          root.typingLegend = menu.body.legend.map(key => MenuKeys.label(key.key));
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
          return named && menu.input.recall() && menu.levels.length === 2 && menu.level.picking && menu.level.entry.list === "agent" && menu.body.filtering;
        }
      },
      {
        name: "a level lays its actions out in its own columns, else menu.body.columns",
        until: () => {
          menu.hide();
          menu.push({ kind: "entry", entry: { submenu: [], columns: 1 } });
          const own = menu.body.columns === 1;
          menu.hide();
          return own && menu.body.columns === Config.menu.columns;
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
        name: "a key path through a pinned entry runs what it runs unpinned, closing the menu it opened",
        start: () => {
          root.pinning(2);
          menu.hide();
          root.pathRan = menu.press("t 2");
          root.pathClosed = !menu.open;
        },
        until: () => root.pathRan && root.pathClosed && Plugins.get("picked")?.text === "b-2" && root.unpinning()
      },
      {
        name: "a pinned entry leaves the top level's rows for its island: its key gives it the keys, where a digit runs its item; with the body's, a digit does nothing",
        start: () => {
          const pin = root.pinning(2);
          const left = !menu.body.items.some(item => item.key === "t") && pin.rows.length === 2 && pin.rows[1].key === "2";
          const body = !menu.handleName("1") && menu.focused === menu.body;
          const focused = menu.handleName("t") && menu.focused === pin && menu.levels.length === 0 && pin.focused && !menu.body.focused;
          root.acted = left && body && focused && menu.handleName("1");
        },
        until: () => root.acted && Plugins.get("picked")?.text === "a-1" && root.unpinning()
      },
      {
        name: "with the body's keys a letter runs its entry, and with a pin's it does not",
        until: () => {
          root.pinning(2);
          menu.handleName("t");
          const pinned = !menu.handleName("a") && menu.levels.length === 0;
          menu.stepBack();
          const opened = menu.focused === menu.body && menu.handleName("a") && menu.level?.entry?.desc === "Audio";
          return pinned && opened && root.unpinning();
        }
      },
      {
        name: "Escape leaves a pin's input for its island, its filter, then the pin for the body, then closes; the keys moving stop a filter",
        until: () => {
          const pin = root.pinning(2);
          menu.handleName("t");
          const typing = menu.handleName("Tab") && menu.inputFocused && menu.input.input.desc === "Add a task...";
          menu.stepBack();
          const island = !menu.inputFocused && menu.focused === pin;
          pin.startFilter();
          const filtering = pin.filtering;
          menu.stepBack();
          const filtered = filtering && !pin.filtering && menu.focused === pin;
          menu.stepBack();
          const body = menu.focused === menu.body && menu.open;
          menu.stepBack();
          const closed = !menu.open;
          root.pinning(2);
          menu.handleName("t");
          pin.startFilter();
          menu.focusIsland("body");
          return typing && island && filtered && body && closed && !pin.filtering && root.unpinning();
        }
      },
      {
        name: "the bar's actions and legend follow the island with the keys, ? keys staying, its slots holding still",
        until: () => {
          root.pinning(2);
          const shown = () => Array.from(header.parts[0].children).filter(child => child.item?.desc).map(child => child.item.desc).join();
          const slots = () => JSON.stringify(menu.barSlots) + Array.from(header.parts[1].children).length;
          const [bodyActions, bodySlots, bodyLegend] = [shown(), slots(), menu.focused.legend.some(key => key.key === "?")];
          menu.handleName("t");
          const followed = bodyActions === "" && bodyLegend && shown() === "Flip" && Array.from(header.parts[0].children).find(child => child.keys)?.keys.some(key => key.key === "?") && slots() === bodySlots;
          return followed && root.unpinning();
        }
      },
      {
        name: "the input is the focused island's, and the visit outlasts the keys moving between islands, never the menu closing",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent) return false;
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          root.pinning(2);
          const visit = menu.visit;
          const asking = menu.input.input.desc === "Ask" && agent.watched;
          menu.handleName("t");
          const tasks = menu.input.input.desc === "Add a task..." && menu.input.draftKey === "[\"t\"]" && agent.watched && menu.visit === visit;
          menu.stepBack();
          const back = menu.input.input.desc === "Ask" && agent.watched;
          menu.hide();
          const ended = !agent.watched;
          Config.menu.input = null;
          return visit !== "" && asking && tasks && back && ended && root.unpinning();
        }
      },
      {
        name: "a right click on a pin's row gives the pin the keys, so stepping back from the item's menu returns to it",
        until: () => {
          const pin = root.pinning(2);
          pinRow.level = pin;
          pinRow.item = { key: "1", desc: "A", actions: [{ key: "d", desc: "Delete", select: () => {} }] };
          pinRow.secondaryActivated();
          const opened = menu.level?.kind === "actions" && menu.focused === menu.body;
          menu.stepBack();
          const back = menu.levels.length === 0 && menu.focused === pin;
          pinRow.level = menu.body;
          return opened && back && root.unpinning();
        }
      },
      {
        name: "opening a level ends the input's visit, where the keys moving to a pin and back do not",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent) return false;
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          root.pinning(2);
          const visit = menu.input.visit;
          menu.handleName("t");
          menu.stepBack();
          const kept = visit !== "" && menu.input.visit === visit && agent.watched;
          menu.handleName("a");
          const ended = menu.input.visit !== visit && !agent.watched;
          Config.menu.input = null;
          return kept && ended && root.unpinning();
        }
      },
      {
        name: "past a pin's limit 0 lists the rest in the body, from which Escape gives the keys back to the pin",
        until: () => {
          const pin = root.pinning(1);
          menu.handleName("t");
          const limited = pin.rows.length === 1 && pin.legend.some(key => key.key === "0");
          const picked = menu.handleName("0") && menu.levels.length === 1 && menu.level.picking && menu.focused === menu.body && menu.body.filtering;
          menu.stepBack();
          return limited && picked && menu.levels.length === 0 && menu.focused === pin && root.unpinning();
        }
      },
      {
        name: "toggleEntry on a pinned entry gives its island the keys, and hides the menu once it has them",
        until: () => {
          const pin = root.pinning(2);
          menu.hide();
          menu.toggleEntry("t");
          const focused = menu.open && menu.focused === pin && menu.levels.length === 0;
          menu.toggleEntry("t");
          return focused && !menu.open && root.unpinning();
        }
      },
      {
        name: "a pinned Wi-Fi list scans while the menu shows, and a pin leaving the layout gives the keys back to the body",
        until: () => {
          root.pinning(2, [{ key: "w", desc: "Wi-Fi", list: "wifi" }]);
          const scanning = Lists.scanning;
          menu.handleName("t");
          Config.menu.layout = ["input", "body", "bar"];
          return scanning && menu.focused === menu.body && root.unpinning() && !Lists.scanning;
        }
      },
      {
        name: "an entry without a layout opens in the body, the pins staying; one with a layout replaces the islands until Escape, which restores them and the island with the keys",
        until: () => {
          const tasks = root.routing();
          const kept = menu.handleName("a") && menu.level?.entry?.desc === "Audio" && menu.modelOf("t") === tasks;
          menu.stepBack();
          menu.handleName("t");
          const replaced = menu.handleName("o") && JSON.stringify(menu.layout) === "[\"input\",\"e\",\"body\",\"bar\"]" && !menu.modelOf("t") && menu.focused === menu.body;
          menu.stepBack();
          const restored = menu.levels.length === 0 && menu.layout.includes("t") && menu.focused === menu.modelOf("t");
          menu.stepBack();
          menu.handleName("c");
          menu.stepBack();
          const body = menu.layout.includes("t") && menu.focused === menu.body;
          return kept && replaced && restored && body && root.unpinning();
        }
      },
      {
        name: "a level whose layout is no list opens in the body of the layout showing",
        until: () => {
          menu.hide();
          menu.levels = [{ kind: "entry", entry: { submenu: [], layout: {} } }];
          const body = menu.home === null && menu.layout.join() === "input,body,bar";
          menu.levels = [];
          return body;
        }
      },
      {
        name: "a pin in an entry's layout leaves that level's rows, takes the keys on its key there, never from a level under it, and shows its input",
        until: () => {
          root.routing();
          menu.handleName("c");
          const events = menu.modelOf("e");
          const left = !menu.body.items.some(item => item.key === "e") && events?.rows.length === 2;
          const focused = menu.handleName("e") && menu.focused === events && menu.input.input?.desc === "Add an event..." && menu.input.draftKey === "[\"c\",\"e\"]";
          menu.stepBack();
          menu.handleName("d");
          const under = !menu.handleName("e") && menu.focused === menu.body && menu.modelOf("e") === events;
          menu.toggleEntry("t");
          const toggled = menu.open && menu.levels.length === 0 && menu.focused === menu.modelOf("t");
          return left && focused && under && toggled && root.unpinning();
        }
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
