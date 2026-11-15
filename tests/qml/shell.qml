import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.builtins
import qs.widgets.menu

// Each case waits up to five seconds for its condition, then prints `ok` or `not ok`; the plugins are config/'s.
ShellRoot {
  id: root

  property int index: -1
  property int waited: 0
  // Every text the watcher has shown, in order.
  property var watched: []
  // The ticker's value a second into the case that waits with the menu closed.
  property string ticked: ""

  readonly property var cases: [
    {
      name: "a read command's last line is its state, plain text its text",
      until: () => Plugins.get("lastLine")?.text === "second"
    },
    {
      name: "a watch's state clears when it exits",
      until: () => root.watched.slice(0, 2).join() === "up,"
    },
    {
      name: "a file is read once it appears",
      start: () => Quickshell.execDetached(["sh", "-c", 'echo /walls/sunset.jpg > "$XDG_RUNTIME_DIR/wallpaper"']),
      until: () => Plugins.get("wallpaper")?.text === "sunset"
    },
    {
      name: "a plugin in the user's folder loads",
      until: () => Plugins.get("custom")?.text === "from the user's folder"
    },
    {
      name: "a plugin in a folder of its own loads, its views created with it",
      until: () => Plugins.get("folded")?.text === "from its folder"
    },
    {
      name: "a plugin's settings are its Settings.qml, set from config.json over its defaults",
      until: () => Plugins.get("folded")?.settings.greeting === "hi" && Plugins.get("folded").settings.count === 3 && !("unknown" in Plugins.get("folded").settings)
    },
    {
      name: "show gives a value its look",
      until: () => Plugins.get("paused")?.glyph === "B" && Plugins.get("paused").tone === "alert" && Plugins.get("paused").active
    },
    {
      name: "a line's own fields win over the look show gives its value",
      until: () => Plugins.get("override")?.text === "live" && Plugins.get("override").detail === "d"
    },
    {
      name: "static items light by value, dim unless enabled, and give the status its label and icon",
      until: () => JSON.stringify((Plugins.get("layouts")?.items ?? []).map(item => [item.id, item.active, item.enabled])) === '[["a",false,true],["b",true,true],["c",false,false]]'
        && Plugins.get("layouts").text === "B" && Plugins.get("layouts").glyph === "I"
    },
    {
      name: "a read with every waits while the menu is closed",
      until: () => {
        if (root.waited === 1000) root.ticked = Plugins.get("ticker")?.text ?? "";
        return root.waited >= 3000 && Plugins.get("ticker")?.text === root.ticked;
      }
    },
    {
      name: "a read with every reads again while the menu is open",
      start: () => Plugins.menuOpen = true,
      until: () => Number(Plugins.get("ticker")?.text) >= Number(root.ticked) + 2
    },
    {
      name: "a plugin that fails to load is left out",
      until: () => Plugins.get("broken") === null && Plugins.get("lastLine") !== null
    },
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
      name: "a month or year away keeps the day, or the month's last when it has fewer",
      until: () => [[new Date(2027, 0, 31), [0, 1, 0]], [new Date(2028, 1, 29), [1, 0, 0]], [new Date(2026, 11, 31), [0, 0, 1]]].map(([from, move]) => {
        menu.calendar.selected = from;
        menu.calendar.moveSelected(...move);
        return Calendar.key(menu.calendar.selected);
      }).join() === "2027-02-28,2029-02-28,2027-01-01"
    },
    {
      name: "an event shows on every day it overlaps, all-day ones first",
      until: () => Calendar.timeline.map(row => row.key.slice(8) + " " + row.event.title).join() ===
        "12 Holiday,12 Night shift,13 Night shift,14 Night shift,20 Trip,21 Trip,25 Call"
    },
    {
      name: "the shell defines each built-in name the module accepts, and no other",
      until: () => {
        const names = JSON.parse(Quickshell.env("BUILTINS"));
        const same = (table, list) => JSON.stringify(Object.keys(table).sort()) === JSON.stringify([...list].sort());
        return same(Statuses.builtin, names.statuses) && same(Lists.builtin, names.lists) && same(States.builtin, names.states) && same(HeaderItems.builtin, names.headerItems);
      }
    }
  ]

  function next() {
    index++;
    if (index === cases.length) {
      console.info("# done");
      Qt.quit();
      return;
    }
    waited = 0;
    cases[index].start?.();
    poll.start();
  }

  Component.onCompleted: next()

  Timer {
    id: poll
    interval: 50
    repeat: true
    onTriggered: {
      const passed = root.cases[root.index].until();
      root.waited += interval;
      if (!passed && root.waited < 5000) return;
      stop();
      console.info((passed ? "ok " : "not ok ") + (root.index + 1) + " - " + root.cases[root.index].name);
      root.next();
    }
  }

  Connections {
    target: Plugins.get("watcher")
    function onTextChanged() {
      root.watched = root.watched.concat([target.text]);
    }
  }

  MenuModel {
    id: menu
  }
}
