import QtQuick
import QtTest
import "keymap.js" as Keymap

// The one key map of the menu on screen, pure: where each key goes under a layout, what `?` lists, and what two may not share.
TestCase {
  name: "keymap"

  readonly property var words: ({ helpMove: "Move", helpRun: "Run", helpEscape: "Back", helpTab: "Tab", helpFilter: "Filter", helpItemMenu: "Menu", helpBarKeys: "Bar", helpSendLeave: "Send", helpRecall: "Recall" })
  readonly property var letters: ["a", "A", "b", "d", "w", "m"].map(key => ({ key, desc: key }))
  readonly property var tasks: [{ key: "s", desc: "Sort" }, { key: "c", desc: "Done" }, { key: "y", desc: "Sync" }].concat([1, 2, 3].map(i => ({ key: String(i), desc: "Task " + i, listed: true })))
  // The owner's: Ask on top, Tasks pinned on t (Sort, Done, Sync; three items, more on 0), the top level's letters with the cursor, the bar's Ctrl keys.
  readonly property var owner: Keymap.rest({
    islands: [
      { name: "t", items: tasks, more: true, filters: true },
      { name: "body", items: letters, pins: [{ key: "t", desc: "Tasks" }], focused: true, free: ["Up", "Down", "Left", "Right"] }
    ],
    bar: [{ key: "x", desc: "X" }, { key: "1", desc: "Tray", app: { hasMenu: true } }],
    holds: { Ctrl: true },
    tab: true,
    words: words
  })
  readonly property var starter: Keymap.rest({ islands: [{ name: "body", items: letters, focused: true, free: ["Up", "Down", "Left", "Right"] }], bar: [{ key: "c", desc: "Calendar" }], words: words })
  readonly property var calendar: [{ key: ["Left", "Right"], desc: "Day" }, { key: ["Up", "Down"], desc: "Week" }, { key: ["Ctrl+Up", "Ctrl+Down"], desc: "Year" }, { key: "t" }, { key: "Return" }]
  readonly property var viewLevel: Keymap.rest({ islands: [{ name: "body", items: [{ key: "Right", desc: "Shadowed" }, { key: "n", desc: "New" }], view: calendar, focused: true }], words: words })

  function to(bindings, name) {
    const hit = Keymap.route(bindings, name);
    return hit ? hit.island + ":" + hit.what : "";
  }

  function test_owner_routes_by_owner() {
    compare(to(owner, "2"), "t:row");
    compare(Keymap.route(owner, "2").item.desc, "Task 2");
    compare(to(owner, "a"), "body:row");
    compare(to(owner, "s"), "t:row");
    compare(to(owner, "t"), "body:pin");
    compare(to(owner, "0"), "t:more");
    compare(to(owner, "/"), "t:filter");
    compare(to(owner, "Ctrl+x"), "bar:bar");
    compare(to(owner, "Ctrl+Alt+1"), "bar:itemMenu");
    compare(to(owner, "Up"), "body:cursor");
    compare(to(owner, "Tab"), ":tab");
    compare(to(owner, "4"), "");
    compare(to(owner, "Escape"), ":back");
    compare(to(owner, ""), "");
    compare(Keymap.overlaps(owner), []);
  }

  // A key path never presses the cursor's keys: they say so.
  function test_cursor_keys() {
    compare(owner.filter(binding => binding.cursor).map(binding => binding.key), ["Up", "Down", "Left", "Right", "Return", "Shift+Return"]);
    compare(Keymap.route(owner, "Return").item, undefined);
  }

  function test_starter() {
    compare(to(starter, "A"), "body:row");
    compare(to(starter, "1"), "");
    compare(to(starter, "Tab"), "");
    compare(to(starter, "Ctrl+c"), "bar:bar");
    compare(Keymap.overlaps(starter), []);
  }

  // Precedence is the table's order: a view's keys, then rows, then the cursor.
  function test_precedence() {
    compare(to(viewLevel, "Right"), "body:view");
    compare(to(viewLevel, "Return"), "body:view");
    compare(to(viewLevel, "n"), "body:row");
    const order = what => owner.findIndex(binding => binding.what === what);
    verify(order("row") < order("bar") && order("bar") < order("cursor"));
  }

  // A view's arrows and Return are its cursor: only while its island has it.
  function test_view_cursor() {
    const pinned = Keymap.rest({ islands: [{ name: "e", view: calendar }, { name: "body", items: letters, focused: true, free: ["Up", "Down"] }] });
    compare(to(pinned, "Up"), "body:cursor");
    compare(to(pinned, "Ctrl+Up"), "e:view");
    compare(to(pinned, "t"), "e:view");
  }

  function test_filter_typing_help_modes() {
    const filtering = Keymap.filtering({ island: "t", rows: [{ id: "a" }], item: { id: "a" }, size: 9 });
    compare(to(filtering, "1"), "t:choose");
    compare(to(filtering, "5"), "t:choose");
    compare(to(filtering, "a"), "");
    compare(Keymap.route(filtering, "Page_Down").by, 9);
    const typing = Keymap.typing({ tab: true, recalls: true, words });
    compare(to(typing, "a"), "");
    compare(to(typing, "Backtab"), ":tab");
    compare(to(typing, "Ctrl+r"), ":recall");
    // Ctrl reaches the bar wherever the keys are: typing, or filtering.
    compare(to(Keymap.typing({ tab: true, bar: [{ key: "x", desc: "X" }] }), "Ctrl+x"), "bar:bar");
    compare(to(Keymap.filtering({ island: "t", rows: [], size: 9, bar: [{ key: "x", desc: "X" }] }), "Ctrl+x"), "bar:bar");
    compare(to(Keymap.helping(), "x"), ":closeHelp");
    compare(to(Keymap.helping(), ""), "");
  }

  // `?` lists each described key once, keys sharing a description as one, in the table's order.
  function test_help() {
    const listed = bindings => Keymap.help(bindings).map(entry => [].concat(entry.key).join() + " " + entry.desc);
    compare(listed(viewLevel), ["Left,Right Day", "Up,Down Week", "Ctrl+Up,Ctrl+Down Year", "Escape Back"]);
    compare(listed(owner), ["Ctrl+ Bar", "t Tasks", "Up,Down,Left,Right Move", "Return Run", "/ Filter", "Tab Tab", "Escape Back"]);
    compare(Keymap.help(owner)[2].paired, true);
    compare(listed(Keymap.typing({ tab: true, words })), ["Tab Tab", "Ctrl+Shift+Return Send", "Escape Back"]);
  }

  // The check: a pin's letter on a body letter, two pinned lists, a bar key the body binds with Ctrl, a view's key on a pin.
  function test_overlaps() {
    const clash = Keymap.overlaps(Keymap.ofLevel({
      entries: [
        { key: "c", desc: "Calendar" },
        { key: "Ctrl+x", desc: "Cut" },
        { key: "t", desc: "Tasks", list: "tasks", limit: 3, submenu: [{ key: "c", desc: "Done" }] },
        { key: "n", desc: "Notes", list: "notes", limit: 2 }
      ],
      pinned: ["t", "n"],
      bar: [{ key: "x", desc: "X" }]
    }, {}));
    compare(clash.map(overlap => overlap.key + ":" + overlap.held.map(binding => binding.island + " " + binding.label).join("+")),
      ["c:body Calendar+t Done", "Ctrl+x:body Cut+bar X", "1:t Tasks+n Notes", "2:t Tasks+n Notes"]);
    const viewed = Keymap.overlaps(Keymap.ofLevel({ entries: [{ key: "t", desc: "Tasks", list: "tasks" }], pinned: ["t"], view: "calendar" }, { calendar: { keys: calendar } }));
    compare(viewed.map(overlap => overlap.key + ":" + overlap.held.map(binding => binding.label).join("+")), ["t:the calendar view+Tasks"]);
    // A pinned list on a level whose body lists too.
    const lists = Keymap.overlaps(Keymap.ofLevel({ entries: [{ key: "e", desc: "Events", list: "events", limit: 2 }], pinned: ["e"], list: "wifi" }, {}));
    compare(lists.map(overlap => overlap.key + ":" + overlap.held.map(binding => binding.island).join("+")), ["1:body+e", "2:body+e"]);
    // A second entry on a pinned key stays a row of the body.
    const twice = Keymap.overlaps(Keymap.ofLevel({ entries: [{ key: "t", desc: "Tasks", list: "tasks" }, { key: "t", desc: "Tea", cmd: "true" }], pinned: ["t"] }, {}));
    compare(twice.map(overlap => overlap.key + ":" + overlap.held.map(binding => binding.what + " " + binding.label).join("+")), ["t:row Tea+pin Tasks"]);
  }

  function test_owner_layout_passes() {
    const level = Keymap.ofLevel({ entries: letters.concat([{ key: "t", desc: "Tasks", list: "tasks", limit: 3, submenu: [{ key: "s" }, { key: "c" }, { key: "y" }] }]), pinned: ["t"], bar: [{ key: "x" }] }, {});
    compare(Keymap.overlaps(level), []);
    compare(to(level, "2"), "t:row");
    compare(to(level, "t"), "body:pin");
  }
}
