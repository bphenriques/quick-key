import QtQuick
import Quickshell
import qs
import qs.builtins
import qs.services
import qs.ui
import qs.widgets.menu
import "ui/places.js" as Places

// What the menu makes of its entries: a list's digits, key names and hints, what an action brings, the bar's keys, an entry's format and the picker over a list.
ShellRoot {
  id: root

  // The legend's keys while an input has the keys.
  property var typingLegend: []
  property int visitStep: 0
  // The agent's visit as it changes: "watched", "unwatched", "ended".
  property var visitLog: []
  property int orderStep: 0
  // Whether a case pressed its key, once.
  property bool pressed: false
  // What a case found as it acted, once; null until it has.
  property var acted: null
  // A one-line prompt's height, once it matched the bar's.
  property real promptLine: 0
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
  readonly property var cursorDown: () => menu.dispatch("Down")
  readonly property var cursorCapital: () => menu.dispatch("Down") && menu.dispatch("Right")

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
    ["Return runs a capital's row too, the cursor being the deliberate step", gridLevel, cursorCapital, "Return", "capital"]
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

  // As typing runs a key, through the key map.
  function pressOn(level, before, name) {
    menu.hide();
    menu.show();
    menu.push(level);
    if (before) before();
    ran = "";
    const was = { held: menu.held, day: menu.body.viewModel?.selected.getTime(), filtering: menu.body.filtering, depth: menu.levels.length, input: menu.inputFocused, cursor: menu.body.cursor.current };
    const did = outcome(menu.dispatch(name), was);
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

  // The bar's icon as the font draws it.
  TextMetrics {
    id: glyphInk
    font.family: Config.theme.monospaceFont
    font.pointSize: Config.theme.iconSize * 0.75
    text: Glyphs.search
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

    MenuRow {
      id: filledRow
      menu: menu
      level: menu.body
      item: ({ key: "1", desc: "x", icon: Glyphs.search })
    }

    // A bar's action, as the tasks' Sort, on a bar too crowded for labels.
    MenuRow {
      id: compactRow
      menu: menu
      level: menu.body
      hugs: true
      compact: true
      item: ({ key: "s", desc: "Sort", icon: Glyphs.search, detail: "by due date" })
    }

    MenuHeader {
      id: header
      y: 40
      menu: menu
      room: 300
    }

    MenuBody {
      id: bodyView
      width: 300
      menu: menu
      level: menu.body
    }

    // The input island's prompt and a bar's icon, as the clock's.
    Prompt {
      id: linePrompt
      width: 300
    }

    HeaderItem {
      id: iconItem
      menu: menu
      item: ({ desc: "Calendar", icon: Glyphs.search })
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
        name: "a stream that names no icon takes its app's desktop entry's, found by its binary",
        until: () => {
          const binary = { "application.name": "Fixture player", "application.process.binary": "fixture-player" };
          return Lists.appIcon(binary) === "fixture-player-icon" && Lists.appIcon(Object.assign({ "application.icon-name": "own" }, binary)) === "own"
            && Lists.appIcon({ "application.name": "Unknown", "application.process.binary": "unknown" }) === "";
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
        name: "the clock shows a glyph of its own, so a bar showing the date and the next event tells them apart",
        until: () => Statuses.of("clock").glyph === Glyphs.clock && Glyphs.clock !== Glyphs.calendar && Statuses.of("calendar").glyph === Glyphs.calendar
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
        until: () => Lists.items("hides").length === 2 && menu.bar.barOf([{ desc: "H", list: "hides", limit: 1 }]).length === 1
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
        name: "keys are named as entries declare them: Shift only picks the capital, a modifier alone has no name",
        until: () => JSON.stringify([
          { key: Qt.Key_A, modifiers: Qt.ShiftModifier, text: "A" },
          { key: Qt.Key_Left, modifiers: Qt.ControlModifier, text: "" },
          { key: Qt.Key_C, modifiers: Qt.ControlModifier | Qt.AltModifier, text: "\u0003" },
          { key: Qt.Key_Question, modifiers: Qt.ShiftModifier, text: "?" },
          { key: Qt.Key_Question, modifiers: Qt.ControlModifier | Qt.ShiftModifier, text: "\u001f" },
          { key: Qt.Key_Shift, modifiers: Qt.ShiftModifier, text: "" },
          { key: Qt.Key_Return, modifiers: Qt.ShiftModifier, text: "\r" },
          { key: Qt.Key_Enter, modifiers: Qt.NoModifier, text: "\r" }
        ].map(event => MenuKeys.name(event))) === '["A","Ctrl+Left","Ctrl+Alt+c","?","Ctrl+?","","Return","Return"]'
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
          menu.dispatch("/");
        },
        until: () => {
          if (!root.pressed && menu.body.filtering && menu.body.filterSlots === 2 && menu.body.rows.length === 2) root.pressed = menu.dispatch("2");
          return root.pressed && Plugins.get("picked")?.text === "b-2";
        }
      },
      {
        name: "a bar entry with a list and a key is one item, opening its level on Ctrl and its key; one without a key shows each item",
        start: () => {
          root.acted = null;
          menu.hide();
          menu.push({ kind: "entry", entry: { submenu: [], bar: { left: [{ key: "b", desc: "Fruits", status: "clicked", list: "devices", submenu: [{ key: "p", desc: "Peel", cmd: "true" }] }],
            right: [{ desc: "Devices", list: "devices" }] } } });
        },
        until: () => {
          if (root.acted === null) {
            if (Lists.items("devices").length !== 2) return false;
            root.acted = JSON.stringify([menu.bar.slots.left.map(item => [item.key, item.desc, item.status]), menu.bar.slots.right.map(item => item.desc)]);
            menu.handleKey({ key: Qt.Key_B, modifiers: Qt.ControlModifier, text: "" });
          }
          const opened = root.acted === '[[["b","Fruits","clicked"]],["a-1","b-2"]]' && menu.level?.entry?.desc === "Fruits" && menu.body.rows.length === 2;
          // Cleared for the cases after, which wait on it being null.
          if (opened) root.acted = null;
          return opened;
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
          if (root.pressed && menu.level?.picking && menu.body.filtering && menu.body.filterSlots === 9 && menu.body.rows.length === 2) root.pressed = !menu.dispatch("2");
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
          const content = menu.body.content && menu.body.barActions.length === 1 && menu.body.bodyActions.length === 0 && !menu.bar.empty;
          const legend = menu.body.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join() === "/ 1-9 of 10000,? keys";
          const listed = menu.help.some(key => key.key === "/");
          menu.handleKey({ key: Qt.Key_Slash, modifiers: Qt.NoModifier, text: "/" });
          const filtering = menu.body.filtering && menu.body.barActions.length === 0;
          menu.hide();
          menu.push({ kind: "entry", entry: { list: "many", submenu: [{ key: "/", desc: "Slash", cmd: "true" }] } });
          const bound = !menu.body.slashFilters && menu.body.legend.map(key => key.key).join() === "?";
          menu.push({ kind: "entry", entry: { submenu: [{ key: "m", desc: "Mute", cmd: "true" }] } });
          const bare = !menu.body.content && menu.body.legend.map(key => key.key).join() === "?";
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
          menu.dispatch("f");
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
        until: () => menu.body.filter.found.length === 280 && menu.body.rows[0].desc === "Item 99" && menu.body.filter.count === "1-9 of 280" && menu.dispatch("5") && menu.body.filter.query === "99 ITEM"
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
          const down = menu.dispatch("Page_Down") && menu.body.filter.index === 9 && menu.body.rows[8].current;
          const up = menu.dispatch("Page_Up") && menu.body.filter.index === 0 && menu.body.rows[0].current;
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
            menu.dispatch("Alt+1");
            const own = menu.level.kind === "actions" && menu.body.items[0].key === "d" && menu.bar.slots.left[0].desc === "A";
            menu.dispatch("d");
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
          menu.dispatch("Down");
          const moved = menu.body.cursorItem?.id === "i3" && menu.body.rows[3].current && menu.body.legend.map(key => MenuKeys.label(key.key) + " " + key.what).join(", ") === "/ 1-9 of 12, ? keys, RET open, M-RET menu";
          for (let i = 0; i < 20; i++) menu.dispatch("Down");
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
        name: "at the top the arrows move over the entries as laid out, ↓ past the last row onto the bar's first stop and ↑ back, Return opens one as its letter would, and Escape back keeps its row",
        until: () => {
          menu.hide();
          menu.show();
          const xOf = children => Array.from(children).find(child => child.item?.key === "x");
          const moved = menu.dispatch("Down") && menu.body.cursor.current === "a" && menu.dispatch("Right") && menu.body.cursor.current === "t";
          // Only the menu's bar shows the cursor, never a panel's strip of statuses.
          barItem.item = menu.bar.items.find(item => item.key === "x");
          const onBar = menu.dispatch("Down") && menu.cursorOnBar && menu.bar.cursorItem?.key === "x" && !menu.body.bodyActions[1].current
            && xOf(header.parts[1].children)?.current && !barItem.current && menu.dispatch("Right") && menu.bar.cursorItem?.desc === "Volume" && menu.dispatch("Left");
          const up = menu.dispatch("Up") && !menu.cursorOnBar && menu.body.cursor.current === "t" && menu.body.bodyActions[1].current && !xOf(header.parts[1].children)?.current
            && menu.dispatch("Left");
          if (!moved || !onBar || !up) console.info("# " + [moved, onBar, up, (menu.bar.stops ?? []).map(stop => stop.id)].join(" | "));
          const opened = menu.dispatch("Return") && menu.level?.entry?.desc === "Audio" && !menu.body.cursorItem;
          menu.stepBack();
          const kept = menu.level === null && menu.body.cursor.current === "a";
          menu.hide();
          return moved && onBar && up && opened && kept;
        }
      },
      {
        name: "at the top Return opens a capital's level as its letter would",
        until: () => {
          menu.hide();
          if (!root.entries) root.entries = Config.menu.entries;
          Config.menu.entries = [{ key: "a", desc: "Audio", submenu: [] }, { key: "A", desc: "Audio input", submenu: [] }];
          menu.show();
          const opened = menu.dispatch("Down") && menu.dispatch("Right") && menu.body.cursor.current === "A" && menu.dispatch("Return") && menu.level?.entry?.desc === "Audio input";
          menu.hide();
          Config.menu.entries = root.entries;
          return opened;
        }
      },
      {
        name: "a bare list level's bar shows ? keys before its cursor, naming Return once it shows, and the top level's bar holds still",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = plugin.items;
          plugin.items = [{ id: "a" }, { id: "b" }];
          menu.hide();
          menu.show();
          menu.push(root.bareLevel);
          const bare = menu.body.legend.map(key => key.key).join() === "?" && menu.dispatch("Down") && !!menu.body.cursorItem && menu.body.legend.map(key => key.key).join() === "?,Return";
          menu.push(root.keyedLevel);
          const named = menu.dispatch("Down") && !menu.bar.empty && menu.body.legend.some(key => key.key === "Return");
          menu.hide();
          menu.show();
          const before = menu.body.legend.length;
          const still = menu.dispatch("Down") && !!menu.body.cursorItem && menu.body.legend.length === before;
          menu.hide();
          plugin.items = was;
          return bare && named && still;
        }
      },
      {
        name: "↓ past the last row enters the bar at its first item a click runs, passing what only shows and stopping on one that dims; RET on the clock opens it and ESC lands back on it, digits and Ctrl keeping their targets, ↑ leaving for the rows",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = plugin.items;
          plugin.items = [{ id: "a", actions: [{ key: "d" }] }, { id: "b", actions: [{ key: "d" }] }];
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "keyed", bar: { left: ["clock", { desc: "Blank", status: "nonesuch", cmd: "true" }, { key: "z", desc: "Dim", action: "nope" },
            { key: "c", desc: "Calendar", status: "clock", view: "calendar" }] } } });
          const menus = () => menu.body.legend.some(key => key.key === "Return" || key.key === "Alt+Return");
          const entered = menu.dispatch("Down") && menu.dispatch("Down") && menus() && menu.dispatch("Down") && menu.cursorOnBar
            && menu.bar.stops.map(stop => stop.item.desc).join() === "Dim,Calendar" && menu.bar.cursorItem?.desc === "Dim" && menu.bar.cursorItem.enabled === false
            && !menus() && !menu.body.rows.some(row => row.current) && menu.help.some(key => key.desc === Words.helpMove && [].concat(key.key).includes("Right"));
          const one = menu.bindings.find(binding => binding.key === "1");
          const digit = one?.island === "body" && one.item.id === "a";
          const ctrl = menu.dispatch("Ctrl+c") && menu.level?.entry?.view === "calendar";
          menu.stepBack();
          const ctrlBack = menu.cursorOnBar && menu.bar.cursorItem?.desc === "Dim";
          const opened = menu.dispatch("Right") && menu.dispatch("Return") && menu.level?.entry?.view === "calendar";
          menu.stepBack();
          const back = menu.cursorOnBar && menu.bar.cursorItem?.desc === "Calendar" && menu.level?.entry?.list === "keyed";
          const up = menu.dispatch("Up") && !menu.cursorOnBar && menu.body.cursorItem?.id === "b" && menu.body.rows[1].current;
          // A click on an item gives it the cursor too, so Escape back from what it opened lands on it.
          Array.from(header.parts[1].children).find(child => child.item?.desc === "Calendar")?.activated();
          menu.stepBack();
          const clicked = menu.cursorOnBar && menu.bar.cursorItem?.desc === "Calendar";
          if (!entered || !digit || !ctrl || !ctrlBack || !opened || !back || !up || !clicked) console.info("# " + [entered, digit, ctrl, ctrlBack, opened, back, up, clicked].join(" | "));
          menu.hide();
          plugin.items = was;
          return entered && digit && ctrl && ctrlBack && opened && back && up && clicked;
        }
      },
      {
        name: "a bar whose actions just fit their labels at rest keeps them as the cursor moves onto a row, its legend naming RET, or onto the bar",
        start: () => {
          const plugin = Plugins.get("keyed");
          root.acted = { step: 0, seen: [], was: plugin.items };
          plugin.items = [{ id: "a", actions: [{ key: "d" }] }, { id: "b", verb: "connect" }];
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "keyed", submenu: [{ key: "m", desc: "Mute", cmd: "true" }, { key: "s", desc: "Speakers and headphones", cmd: "true" }],
            bar: { left: [{ key: "v", desc: "Vee", cmd: "true", keepOpen: true }] } } });
        },
        // A step a poll, as the bar lays itself out between them: laid out, room for every label and no more, then ↓ onto each row and the bar.
        until: () => {
          const at = root.acted;
          if (at.passed !== undefined) return at.passed;
          if (at.step === 1) header.room += header.labelledWidth + 1 - header.actionsRoom;
          if (at.step > 1) at.seen.push(header.compact);
          // On a row, the legend it shows is all the room kept for it.
          if (at.step === 3) at.seen.push(header.room - header.slotsWidth - header.actionsRoom < Array.from(header.parts[0].children).find(child => child.keys).implicitWidth);
          if (at.step > 1 && at.step < 5) menu.dispatch("Down");
          if (++at.step <= 5) return false;
          at.passed = !at.seen.some(compact => compact) && menu.cursorOnBar;
          if (!at.passed) console.info("# " + [at.seen, menu.cursorOnBar].join(" | "));
          header.room = 300;
          menu.hide();
          Plugins.get("keyed").items = at.was;
          if (at.passed) root.acted = null;
          return at.passed;
        }
      },
      {
        name: "a click on a bar item leaves the input and the filter, one cursor standing; a bar left with no stops gives the cursor back for good",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = plugin.items;
          plugin.items = [{ id: "a", actions: [{ key: "d" }] }];
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "keyed", bar: { left: [{ key: "c", desc: "Calendar", status: "clock", view: "calendar" }] } } });
          const click = () => Array.from(header.parts[1].children).find(child => child.item?.desc === "Calendar")?.activated();
          menu.body.startFilter();
          click();
          menu.stepBack();
          const filter = menu.cursorOnBar && !menu.body.filtering && !menu.inputFocused;
          menu.focusOn("input");
          click();
          menu.stepBack();
          const input = menu.cursorOnBar && !menu.inputFocused;
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "keyed", bar: { left: [{ desc: "Items", list: "keyed" }] } } });
          const on = menu.dispatch("Down") && menu.dispatch("Down") && menu.cursorOnBar;
          plugin.items = [];
          plugin.items = [{ id: "a", actions: [{ key: "d" }] }];
          const gone = !menu.cursorOnBar;
          if (!filter || !input || !on || !gone) console.info("# " + [filter, input, on, gone].join(" | "));
          menu.hide();
          plugin.items = was;
          return filter && input && on && gone;
        }
      },
      {
        name: "on a level whose rows take ←→ the bar's cursor passes their pair, which RET cannot run, stays put as they step, and ? names only ↑↓ as moving it",
        until: () => {
          const plugin = Plugins.get("keyed");
          if (!plugin) return false;
          const was = [plugin.items, plugin.actions];
          let steps = 0;
          let mutes = 0;
          plugin.items = [{ id: "a" }];
          plugin.actions = { step: { pair: true, icon: () => "", available: () => true, run: () => steps++ }, mute: { icon: () => "", available: () => true, run: () => mutes++ } };
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "keyed", submenu: [{ key: ["Left", "Right"], desc: "Step", action: "step" }, { key: "m", desc: "Mute", action: "mute" }],
            bar: { left: [{ key: "v", desc: "Vee", cmd: "true", keepOpen: true }] } } });
          const on = menu.dispatch("Down") && menu.dispatch("Down") && menu.cursorOnBar && menu.bar.cursorItem?.desc === "Mute";
          const still = menu.dispatch("Right") && steps === 1 && menu.bar.cursorItem?.desc === "Mute";
          const runs = menu.dispatch("Return") && mutes === 1;
          const moves = menu.help.filter(key => key.desc === Words.helpMove).map(key => [].concat(key.key).join()).join();
          menu.hide();
          plugin.items = was[0];
          plugin.actions = was[1];
          return on && still && runs && moves === "Up,Down";
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
          menu.dispatch("Down");
          menu.dispatch("Down");
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
        name: "? lists only keys that act: a hold while it lists something, the arrows each pair a level leaves free, RET on a grid, M-1 while an item has its own menu; every level's bar shows ?",
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
            && hinted() && listed({ kind: "entry", entry: { list: "devices" } }) === "Up,Down,/,Escape"
            && listed(null).includes(",Up,Down,Left,Right,Return,") && listed(root.gridLevel) === "Up,Down,Left,Right,Return,Escape"
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
          const without = menu.input.input === null && !menu.body.slashFilters && !menu.dispatch("Tab") && !menu.inputFocused;
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
        name: "menu.keysHint off leaves ? off the bar, and ? still lists the keys",
        until: () => {
          menu.hide();
          Config.menu.keysHint = false;
          menu.levels = [];
          const hidden = !menu.body.legend.some(key => key.key === "?") && menu.dispatch("?") && menu.held === "Help";
          menu.dispatch("?");
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
        name: "in the body Tab and Shift+Tab both move to a level's one input, and back",
        until: () => {
          menu.levels = [{ kind: "entry", entry: { submenu: [], input: { desc: "Add", cmd: "true" } } }];
          menu.focusOn("body");
          const tab = { key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" };
          const backtab = { key: Qt.Key_Backtab, modifiers: Qt.ShiftModifier, text: "" };
          const back = menu.handleKey(backtab) && menu.inputFocused && menu.handleKey(backtab) && !menu.inputFocused;
          return back && menu.handleKey(tab) && menu.inputFocused && menu.handleKey(tab) && !menu.inputFocused;
        }
      },
      {
        name: "↑ past the body's first row lands on the pinned level's last row, ↓ past its last back on the body's first; nothing lies above it, and ←→ never cross",
        until: () => {
          const pin = root.pinning(2);
          const key = code => menu.handleKey({ key: code, modifiers: Qt.NoModifier, text: "" });
          const onBody = key(Qt.Key_Down) && menu.body.cursor.current === "a" && key(Qt.Key_Left) && menu.focused === menu.body;
          const up = key(Qt.Key_Up) && menu.focused === pin && pin.cursor.current === "b-2" && pin.rows[1].current;
          const top = key(Qt.Key_Up) && key(Qt.Key_Up) && menu.focused === pin && pin.cursor.current === "a-1";
          const down = key(Qt.Key_Down) && key(Qt.Key_Down) && menu.focused === menu.body && menu.body.cursor.current === "a" && !pin.rows.some(row => row.current);
          return onBody && up && top && down && root.unpinning();
        }
      },
      {
        name: "TAB visits the input of the island with the cursor, then each other on screen top to bottom, then the rows it left; S-TAB the reverse",
        until: () => {
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          const pin = root.pinning(2);
          const tab = { key: Qt.Key_Tab, modifiers: Qt.NoModifier, text: "\t" };
          const backtab = { key: Qt.Key_Backtab, modifiers: Qt.ShiftModifier, text: "" };
          const at = () => menu.inputFocused ? menu.input.input?.desc : menu.focused === menu.body ? "body" : menu.focused.island;
          const steps = [tab, tab, tab, backtab, backtab, backtab].map(key => menu.handleKey(key) && at());
          menu.dispatch("t");
          const fromPin = [tab, tab, tab].map(key => menu.handleKey(key) && at());
          Config.menu.input = null;
          if (steps.join() !== "Ask,Add a task...,body,Add a task...,Ask,body" || fromPin.join() !== "Add a task...,Ask,t") console.info("# " + steps.join() + " / " + fromPin.join());
          return steps.join() === "Ask,Add a task...,body,Add a task...,Ask,body" && fromPin.join() === "Add a task...,Ask,t" && pin.focused && root.unpinning();
        }
      },
      {
        name: "every message of a visit carries the input's context, each shown as typed; expanding holds the visit, and stepping back returns to the level with the input focused",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent || agent.busy) return false;
          switch (root.visitStep) {
          case 0:
            menu.hide();
            menu.show();
            menu.push({ kind: "entry", entry: { submenu: [], input: { desc: "Add", plugin: "agent", context: "Tasks" } } });
            root.visitStep = menu.input.submit("one", false) ? 1 : -1;
            return false;
          case 1:
            root.visitStep = agent.turn?.question === "one" && agent.turn?.text.endsWith("[Tasks]") && menu.input.submit("two", false) ? 2 : -1;
            return false;
          case 2:
            if (agent.turn?.question !== "two" || !agent.turn?.text.endsWith("[Tasks]")) return false;
            const token = menu.input.lastVisit;
            menu.input.expand();
            // Under the panel, the menu keeps its level and the visit.
            const held = agent.shown && !menu.open && menu.inStack && menu.input.lastVisit === token;
            Panels.back();
            root.visitStep = held && menu.open && menu.levels.length === 1 && menu.inputFocused && menu.input.lastVisit === token && agent.turn?.question === "two" ? 3 : -1;
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
          return root.pathRan && map.includes("- `Ctrl+x` X") && map.includes("- `Ctrl+Down` `Ctrl+Up` Volume") && map.includes("  - `a Ctrl+v` Vee") && map.includes("- `Ctrl+1` `Ctrl+0` Devices") && Plugins.get("picked")?.text === "bar";
        }
      },
      {
        name: "a key path starts from rest whatever the open menu holds: the input focused, ? showing",
        until: () => {
          menu.hide();
          menu.show();
          menu.focusOn("input");
          const typing = menu.press("a") && menu.level?.entry?.desc === "Audio" && !menu.inputFocused;
          menu.hold("Help");
          const helping = menu.press("a a") && menu.levels.length === 2 && menu.held === "";
          menu.hide();
          return typing && helping;
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
        name: "the whole list a pinned list's 0 or a bar's +N opens names its pins by their labels",
        until: () => {
          if (Lists.items("devices").length !== 2) return false;
          const pins = [{ match: "b-*", label: "Bee" }];
          root.pinning(1);
          menu.hide();
          Config.menu.entries = [Object.assign({}, Config.menu.entries[0], { pins })].concat(Config.menu.entries.slice(1));
          menu.show();
          const labels = () => menu.body.filter.items.map(item => item.desc).join();
          const pinned = menu.dispatch("0") && menu.level?.picking && labels() === "Bee,a-1";
          root.unpinning();
          menu.show();
          menu.bar.barOf([{ desc: "D", list: "devices", limit: 1, pins }]).find(item => item.key === "0")?.select();
          const barred = menu.level?.picking && labels() === "Bee,a-1";
          if (!pinned || !barred) console.info("# " + [pinned, barred, labels()].join(" | "));
          menu.hide();
          return pinned && barred;
        }
      },
      {
        name: "an action keeps the menu open, keepOpen = false as unset",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          let ran = 0;
          plugin.actions = { flip: { icon: () => Glyphs.search, available: () => true, run: () => ran++ } };
          menu.hide();
          menu.show();
          menu.push({ kind: "entry", entry: { list: "devices", submenu: [{ key: "f", desc: "Flip", action: "flip", keepOpen: false }] } });
          menu.dispatch("f");
          const open = menu.open && menu.levels.length === 1;
          menu.hide();
          plugin.actions = {};
          return ran === 1 && open;
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
          // Held, Return acts once on the cursor's row, a capital's too.
          const awake = KeepAwake.enabled;
          menu.push({ kind: "entry", entry: { submenu: [{ key: "I", desc: "Awake", action: "keepAwake" }] } });
          menu.dispatch("Down");
          for (const repeat of [false, true]) menu.handleKey({ key: Qt.Key_Return, modifiers: Qt.NoModifier, text: "\r", isAutoRepeat: repeat });
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
        name: "a pinned entry leaves the top level's rows for its island: its key gives it the cursor, where a digit runs its item",
        start: () => {
          const pin = root.pinning(2);
          const left = !menu.body.items.some(item => item.key === "t") && pin.rows.length === 2 && pin.rows[1].key === "2";
          const focused = menu.dispatch("t") && menu.focused === pin && menu.levels.length === 0 && pin.focused && !menu.body.focused;
          root.acted = left && focused && menu.dispatch("1");
        },
        until: () => root.acted && Plugins.get("picked")?.text === "a-1" && root.unpinning()
      },
      {
        name: "with a level pinned, its digit at open runs its item, the cursor staying in the body",
        start: () => {
          root.acted = null;
          Quickshell.execDetached(["sh", "-c", "echo none > \"$XDG_RUNTIME_DIR/picked\""]);
        },
        until: () => {
          if (root.acted === null) {
            if (Plugins.get("picked")?.text !== "none") return false;
            root.pinning(2);
            root.acted = menu.handleKey({ key: Qt.Key_2, modifiers: Qt.NoModifier, text: "2" }) && menu.focused === menu.body && menu.levels.length === 0;
            return false;
          }
          return root.acted && Plugins.get("picked")?.text === "b-2" && root.unpinning();
        }
      },
      {
        name: "a key goes to the island holding it wherever the cursor is: the pin's action from the body, the body's letter from the pin",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          let flipped = 0;
          plugin.actions = { flip: { icon: () => "", available: () => true, run: () => flipped++ } };
          root.pinning(2);
          const key = (code, text) => ({ key: code, modifiers: Qt.NoModifier, text });
          const ran = menu.handleKey(key(Qt.Key_F, "f")) && flipped === 1 && menu.focused === menu.body && menu.levels.length === 0;
          menu.handleKey(key(Qt.Key_T, "t"));
          const pinned = menu.focused === menu.modelOf("t");
          const opened = menu.handleKey(key(Qt.Key_A, "a")) && menu.level?.entry?.desc === "Audio";
          plugin.actions = {};
          return ran && pinned && opened && root.unpinning();
        }
      },
      {
        name: "a key path's digit runs the pinned level's item, as the path through it does",
        start: () => {
          root.acted = null;
          Quickshell.execDetached(["sh", "-c", "echo none > \"$XDG_RUNTIME_DIR/picked\""]);
        },
        until: () => {
          if (root.acted === null) {
            if (Plugins.get("picked")?.text !== "none") return false;
            root.pinning(2);
            menu.hide();
            root.acted = menu.press("1") && !menu.open;
            return false;
          }
          return root.acted && Plugins.get("picked")?.text === "a-1" && root.unpinning();
        }
      },
      {
        name: "on a calendar pinning a list, the bar names the view's RET only while the body has the cursor, the list's once it does",
        until: () => {
          menu.hide();
          if (!root.entries) root.entries = Config.menu.entries;
          Config.menu.entries = [{ key: "c", desc: "Calendar", view: "calendar", layout: ["input", { level: "e" }, "body", "bar"], submenu: [{ key: "e", desc: "Events", list: "devices", limit: 2 }] }];
          menu.show();
          menu.dispatch("c");
          const returns = () => menu.bar.legend.filter(key => key.key === "Return").map(key => key.what).join();
          const body = returns() === Words.events;
          menu.dispatch("e");
          menu.dispatch("Down");
          const pinned = menu.focused === menu.modelOf("e") && returns() === Words.pick;
          if (!body || !pinned) console.info("# " + returns());
          return body && pinned && root.unpinning();
        }
      },
      {
        name: "Ctrl reaches the bar from the input too, as what the text leaves",
        start: () => {
          root.acted = null;
          Quickshell.execDetached(["sh", "-c", "echo none > \"$XDG_RUNTIME_DIR/picked\""]);
        },
        until: () => {
          if (root.acted === null) {
            if (Plugins.get("picked")?.text !== "none") return false;
            Config.menu.input = { desc: "Ask", cmd: "true" };
            menu.hide();
            menu.show();
            menu.focusOn("input");
            root.acted = menu.inputFocused && menu.handleKey({ key: Qt.Key_X, modifiers: Qt.ControlModifier, text: "" });
            Config.menu.input = null;
            return false;
          }
          return root.acted && Plugins.get("picked")?.text === "bar";
        }
      },
      {
        name: "/ from the body filters the pinned list, which takes the cursor, as its filter is typed in the input",
        until: () => {
          const pin = root.pinning(2);
          const filtering = menu.handleKey({ key: Qt.Key_Slash, modifiers: Qt.NoModifier, text: "/" }) && menu.focused === pin && pin.filtering && !menu.inputEmpty;
          menu.stepBack();
          return filtering && !pin.filtering && root.unpinning();
        }
      },
      {
        name: "? lists the keys no row shows on every island: the pinned list's / beside the body's arrows, and the key of each pinned level",
        until: () => {
          root.pinning(2);
          const listed = menu.help.map(key => [].concat(key.key).join()).join(" ");
          return listed.includes("/") && menu.help.some(key => key.key === "t" && key.desc === "Tasks") && listed.includes("Up,Down,Left,Right") && root.unpinning();
        }
      },
      {
        name: "Escape leaves a pin's input for its island, its filter, then the pin for the body, then closes; the keys moving stop a filter",
        until: () => {
          const pin = root.pinning(2);
          menu.dispatch("t");
          const typing = menu.dispatch("Tab") && menu.inputFocused && menu.input.input.desc === "Add a task...";
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
          menu.dispatch("t");
          pin.startFilter();
          menu.focusIsland("body");
          return typing && island && filtered && body && closed && !pin.filtering && root.unpinning();
        }
      },
      {
        name: "the bar is the cursor island's: its actions and legend, then its level's slots, so a pin's is its keys alone; Ctrl still reaches the body's bar, and a pin's actions act from the body as ? lists them",
        until: () => {
          const plugin = Plugins.get("devices");
          if (!plugin) return false;
          let flipped = 0;
          plugin.actions = { flip: { icon: () => "", available: () => true, run: () => flipped++ } };
          root.pinning(1);
          const shown = () => Array.from(header.parts[0].children).filter(child => child.item?.desc).map(child => child.item.desc).join();
          const legend = () => Array.from(header.parts[0].children).find(child => child.keys)?.keys.map(key => [].concat(key.key).join("+")).join() ?? "";
          const slots = () => JSON.stringify(menu.bar.slots) + Array.from(header.parts[1].children).filter(child => child.item).length;
          const listed = () => menu.help.some(key => key.key === "f" && key.desc === "Flip");
          const [bodyActions, bodySlots, bodyLegend, ctrl] = [shown(), slots(), legend(), menu.holds.Ctrl.length];
          const body = bodyActions === "" && bodyLegend === "?" && listed() && menu.dispatch("f") && flipped === 1 && menu.focused === menu.body && slots().endsWith("3");
          menu.dispatch("t");
          const pinned = shown() === "Flip" && legend().split(",").includes("0") && legend().split(",").filter(key => key === "?").length === 1 && !listed()
            && menu.bar.items.length === 0 && slots().endsWith("0") && menu.holds.Ctrl.length === ctrl && menu.dispatch("Ctrl+Down") && menu.open && menu.focused.island === "t" && !menu.bar.empty;
          const pinnedLegend = legend();
          menu.stepBack();
          const back = shown() === "" && legend() === bodyLegend && slots() === bodySlots;
          if (!body || !pinned || !back) console.info("# " + [bodyActions, bodyLegend, listed(), flipped, pinnedLegend, shown()].join(" | "));
          plugin.actions = {};
          return body && pinned && back && root.unpinning();
        }
      },
      {
        name: "the bar is empty only while no island the cursor may be on has anything for it, so the cursor moving never adds or removes it",
        until: () => {
          const was = [Config.menu.bar.left, Config.menu.bar.center, Config.menu.bar.right];
          Config.menu.bar.left = Config.menu.bar.center = Config.menu.bar.right = [];
          Config.menu.keysHint = false;
          root.pinning(2);
          const onBody = !menu.bar.empty;
          menu.dispatch("t");
          const onPin = !menu.bar.empty;
          Config.menu.bar.left = was[0];
          Config.menu.bar.center = was[1];
          Config.menu.bar.right = was[2];
          Config.menu.keysHint = true;
          return onBody && onPin && root.unpinning();
        }
      },
      {
        name: "under [ body {t} bar ] ↓ past the pin's last row enters its bar, its keys alone, and Escape gives the cursor back to the pin, then to the body",
        until: () => {
          root.pinning(2);
          menu.hide();
          Config.menu.layout = ["body", { level: "t" }, "bar"];
          menu.show();
          const pin = menu.modelOf("t");
          menu.dispatch("t");
          const entered = menu.dispatch("Down") && menu.dispatch("Down") && menu.dispatch("Down") && menu.cursorOnBar && menu.focused === pin
            && menu.bar.items.length === 0 && menu.bar.cursorItem?.desc === "Flip" && menu.bar.cursorItem.enabled === false && !pin.rows.some(row => row.current);
          menu.stepBack();
          const toPin = !menu.cursorOnBar && menu.focused === pin;
          menu.stepBack();
          const toBody = menu.focused === menu.body;
          if (!entered || !toPin || !toBody) console.info("# " + [entered, toPin, toBody, (menu.bar.stops ?? []).map(stop => stop.id)].join(" | "));
          return entered && toPin && toBody && root.unpinning();
        }
      },
      {
        name: "an island with nothing shows empty while one farther from the edge shows: a pinned level stays put over an empty input as the keys move, and a filter fills the input",
        until: () => {
          root.pinning(2);
          const shown = () => Places.shown(menu.layout.map(island => island === "input" ? menu.inputEmpty : island === "bar" ? menu.bar.empty : false));
          // Each island as tall whichever has the keys, so only which show moves the pin.
          const pinY = () => Places.of([30, 60, 200, 40], shown(), menu.layout.indexOf("body"), 1000, 35, 4)[menu.layout.indexOf("t")].y;
          menu.hide();
          Config.menu.layout = [{ level: "t" }, "input", "body", "bar"];
          menu.show();
          const under = pinY();
          const empty = menu.inputEmpty;
          menu.dispatch("t");
          const held = empty && !menu.inputEmpty && pinY() === under;
          menu.push(root.bareLevel);
          const bare = menu.inputEmpty;
          menu.body.startFilter();
          const filtering = menu.body.filtering && !menu.inputEmpty;
          return held && bare && filtering && root.unpinning();
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
          menu.dispatch("t");
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
          const visit = menu.input.lastVisit;
          menu.dispatch("t");
          menu.stepBack();
          const kept = visit !== "" && menu.input.lastVisit === visit && agent.watched;
          menu.dispatch("a");
          const ended = menu.input.lastVisit !== visit && !agent.watched;
          menu.stepBack();
          const again = menu.input.lastVisit === visit && agent.watched && agent.displayed;
          Config.menu.input = null;
          return kept && ended && again && root.unpinning();
        }
      },
      {
        name: "opening an entry with a layout of its own ends the input's visit, as its levels and layout change at once",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent) return false;
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          root.routing();
          const asking = agent.watched;
          menu.dispatch("c");
          const ended = menu.input.plugin === null && !agent.watched;
          Config.menu.input = null;
          return asking && ended && root.unpinning();
        }
      },
      {
        name: "an answer finishing while a pin has the keys is notified and marked unread, and shows above the input, read, once Escape gives the body the keys",
        start: () => {
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          root.pinning(2);
          root.acted = null;
        },
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent || agent.busy && root.acted === null) return false;
          if (root.acted === null) {
            root.acted = menu.input.submit("pinned", false) && menu.dispatch("t") && agent.watched && !agent.displayed;
            return false;
          }
          if (agent.busy) return false;
          if (!agent.unread || !Plugins.get("notified")?.text.startsWith("agent|pinned")) return false;
          menu.stepBack();
          const shown = agent.displayed && agent.turn?.question === "pinned" && agent.turn.phase === "done" && !agent.unread;
          Config.menu.input = null;
          return root.acted && shown && root.unpinning();
        }
      },
      {
        name: "opening an entry with a layout of its own from a top level asking ends the visit once, never watching again on the way",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent) return false;
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          root.routing();
          root.visitLog = [];
          menu.dispatch("c");
          const log = root.visitLog.join();
          if (log !== "unwatched,ended") console.info("# " + log);
          Config.menu.input = null;
          return log === "unwatched,ended" && root.unpinning();
        }
      },
      {
        name: "a level opened from a pin whose input asks ends its visit",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent) return false;
          root.pinning(1);
          menu.hide();
          Config.menu.entries = [Object.assign({}, Config.menu.entries[0], { input: { desc: "Ask", plugin: "agent" } }), Config.menu.entries[1]];
          menu.show();
          menu.dispatch("t");
          const asking = menu.input.plugin === agent && agent.watched;
          menu.dispatch("0");
          const ended = menu.level?.picking && !agent.watched;
          return asking && ended && root.unpinning();
        }
      },
      {
        name: "the keys moving to a pin and back, and Ask's panel opening over the menu and closing, end no visit",
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent) return false;
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          root.pinning(2);
          root.visitLog = [];
          menu.dispatch("t");
          menu.stepBack();
          menu.input.expand();
          Panels.back();
          const kept = root.visitLog.length === 0 && menu.open && agent.watched && agent.displayed;
          Config.menu.input = null;
          return kept && root.unpinning();
        }
      },
      {
        name: "an answer finishing while another agent's panel covers the menu is notified and marked unread, and read once the menu shows it again",
        start: () => {
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          menu.hide();
          menu.show();
          root.acted = null;
        },
        until: () => {
          const agent = Plugins.get("agent");
          const other = Plugins.get("other");
          if (!agent || !other || agent.busy && root.acted === null) return false;
          if (root.acted === null) {
            const sent = menu.input.submit("covered", false) && agent.displayed;
            other.show();
            root.acted = sent && !menu.open && menu.inStack && agent.watched && !agent.displayed;
            return false;
          }
          if (agent.busy || !Plugins.get("notified")?.text.startsWith("agent|covered")) return false;
          const unread = agent.unread;
          Panels.back();
          const read = menu.open && agent.displayed && !agent.unread;
          Config.menu.input = null;
          menu.hide();
          return root.acted && unread && read;
        }
      },
      {
        name: "an answer finishing while the menu is closed stays unread as it opens again, the new visit not showing it",
        start: () => {
          Config.menu.input = { desc: "Ask", plugin: "agent" };
          menu.hide();
          menu.show();
          root.acted = null;
        },
        until: () => {
          const agent = Plugins.get("agent");
          if (!agent || agent.busy && root.acted === null) return false;
          if (root.acted === null) {
            root.acted = menu.input.submit("closed", false);
            menu.hide();
            return false;
          }
          if (agent.busy || !agent.unread) return false;
          menu.show();
          const unread = agent.displayed && agent.unread;
          Config.menu.input = null;
          menu.hide();
          return root.acted && unread;
        }
      },
      {
        name: "a pinned list setting no limit shows nine items, 0 listing the rest",
        start: () => root.pinning(2, [{ key: "m", desc: "Many", list: "many" }]),
        until: () => {
          const pin = menu.modelOf("m");
          return pin?.rows.length === 9 && pin.legend.some(key => key.key === "0") && root.unpinning();
        }
      },
      {
        name: "past a pin's limit 0 lists the rest in the body, the pin stepping aside, and Escape gives the keys back to the pin",
        until: () => {
          const pin = root.pinning(1);
          menu.dispatch("t");
          const limited = pin.rows.length === 1 && pin.legend.some(key => key.key === "0");
          const picked = menu.dispatch("0") && menu.levels.length === 1 && menu.level.picking && menu.focused === menu.body && menu.body.filtering
            && !menu.layout.includes("t") && menu.pinnedLevels.length === 0;
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
          menu.dispatch("t");
          Config.menu.layout = ["input", "body", "bar"];
          return scanning && menu.focused === menu.body && root.unpinning() && !Lists.scanning;
        }
      },
      {
        name: "an entry without a layout opens in the body, the pins stepping aside until Escape brings them back as they were; one with a layout replaces the islands until Escape, which restores them and the island with the keys",
        until: () => {
          const tasks = root.routing();
          const aside = menu.dispatch("a") && menu.level?.entry?.desc === "Audio" && menu.layout.join() === "input,body,bar" && menu.pinnedLevels.length === 0 && !menu.modelOf("t");
          menu.stepBack();
          const kept = menu.layout.join() === "input,t,body,bar" && menu.modelOf("t") === tasks && menu.focused === menu.body;
          menu.dispatch("t");
          const replaced = menu.dispatch("o") && JSON.stringify(menu.layout) === "[\"input\",\"e\",\"body\",\"bar\"]" && !menu.modelOf("t") && menu.focused === menu.body;
          menu.stepBack();
          const restored = menu.levels.length === 0 && menu.layout.includes("t") && menu.focused === menu.modelOf("t");
          menu.stepBack();
          menu.dispatch("c");
          menu.stepBack();
          const body = menu.layout.includes("t") && menu.focused === menu.body;
          return aside && kept && replaced && restored && body && root.unpinning();
        }
      },
      {
        name: "height = 5 holds a level of two rows at least five rows tall, menu.height a level setting none, a view fitting",
        until: () => {
          menu.hide();
          const rows = [{ key: "f", desc: "F", cmd: "true" }, { key: "g", desc: "G", cmd: "true" }];
          const held = height => {
            menu.levels = [{ kind: "entry", entry: { submenu: rows, height } }];
            return menu.body.minRows;
          };
          const least = held(5) === 5;
          const fits = held(undefined) === 0;
          Config.menu.height = 4;
          const inherited = held(undefined) === 4;
          menu.levels = [root.calendarLevel];
          const view = menu.body.minRows === 0;
          Config.menu.height = null;
          menu.levels = [];
          return least && fits && inherited && view;
        }
      },
      {
        name: "a menu's numbered rows and letters at height 4 are as tall as its body draws them, and two rows more add two rows",
        start: () => {
          menu.hide();
          const rows = ["1", "2", "a", "b"].map(key => ({ key, desc: key, icon: Glyphs.search, cmd: "true" }));
          menu.levels = [{ kind: "entry", entry: { submenu: rows, columns: 1, height: 4 } }];
        },
        until: () => {
          if (bodyView.implicitHeight !== menu.body.minHeight) return false;
          menu.levels = [{ kind: "entry", entry: { submenu: menu.level.entry.submenu, columns: 1, height: 6 } }];
          const more = menu.body.minHeight === bodyView.implicitHeight + 2 * Metrics.row;
          menu.levels = [];
          return more;
        }
      },
      {
        name: "a level's height counts rows as tall as a filled row draws, at the font as it changes",
        start: () => {
          root.acted = Metrics.row === filledRow.implicitHeight;
          Config.theme.fontSize = 14;
        },
        until: () => {
          const followed = Metrics.row === filledRow.implicitHeight && Metrics.row > 34;
          if (followed) Config.theme.fontSize = 11;
          return root.acted && followed;
        }
      },
      {
        name: "a one-line prompt's island is as tall as the bar's, and three lines grow it by two",
        until: () => {
          // Padded as Menu pads their islands: half the theme's padding for the input, a quarter for the bar; once the bar's item is laid out at the font the case before restored.
          if (!root.promptLine && iconItem.implicitHeight === Metrics.row && linePrompt.implicitHeight + Config.theme.padding === iconItem.implicitHeight + Config.theme.padding / 2) {
            root.promptLine = linePrompt.implicitHeight;
            linePrompt.text = "one\ntwo\nthree";
          }
          return root.promptLine > 0 && Math.abs(linePrompt.implicitHeight - root.promptLine - 2 * Math.ceil(Metrics.line)) < 1;
        }
      },
      {
        name: "a bar's glyph is as wide as its ink, which meets the item's padding as a letter does, never its icon square",
        until: () => glyphInk.tightBoundingRect.width > 0 && glyphInk.tightBoundingRect.width !== Config.theme.iconSize
          && Math.abs(iconItem.implicitWidth - glyphInk.tightBoundingRect.width - 2 * Metrics.itemPaddingX) < 0.5
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
        name: "a pin in an entry's layout shows on that level only, leaving its rows, taking the keys on its key there and showing its input; a level under it shows none, and Escape brings it back",
        until: () => {
          root.routing();
          menu.dispatch("c");
          const events = menu.modelOf("e");
          const left = menu.layout.join() === "input,e,body,bar" && !menu.body.items.some(item => item.key === "e") && events?.rows.length === 2;
          const focused = menu.dispatch("e") && menu.focused === events && menu.input.input?.desc === "Add an event..." && menu.input.draftKey === "[\"c\",\"e\"]";
          menu.stepBack();
          menu.dispatch("d");
          const under = !menu.dispatch("e") && menu.focused === menu.body && menu.layout.join() === "input,body,bar" && !menu.modelOf("e");
          menu.stepBack();
          const back = menu.level?.entry?.desc === "Calendar" && menu.modelOf("e") === events && menu.focused === menu.body;
          menu.toggleEntry("t");
          const toggled = menu.open && menu.levels.length === 0 && menu.focused === menu.modelOf("t");
          return left && focused && under && back && toggled && root.unpinning();
        }
      },
      {
        name: "a bar entry showing only a plugin's status takes a click, which activates the plugin",
        start: () => {
          menu.hide();
          barItem.item = menu.bar.slots.left.find(item => item.key === "k");
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
        name: "a crowded bar shows an action by its glyph alone, its name and value in its tip",
        until: () => {
          const status = Array.from(compactRow.content).find(child => child instanceof MenuStatus);
          return status.detail === "" && status.text === "" && root.tipOf(compactRow) === "Sort, by due date";
        }
      },
      {
        name: "a crowded bar keeps an action's value beside its glyph while it warns",
        start: () => compactRow.item = Object.assign({}, compactRow.item, { tone: "warning" }),
        until: () => Array.from(compactRow.content).find(child => child instanceof MenuStatus).detail === "by due date"
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

  Connections {
    target: Plugins.get("agent")

    function onWatchedChanged() {
      root.visitLog = root.visitLog.concat([target.watched ? "watched" : "unwatched"]);
    }

    function onVisitEnded() {
      root.visitLog = root.visitLog.concat(["ended"]);
    }
  }
}
