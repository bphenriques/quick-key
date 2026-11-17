import QtQuick
import Quickshell
import qs.services
import qs.ui

// How plugins load, read their source and turn its state into what they show; qs.ui is imported for the shipped ones.
ShellRoot {
  id: root

  // Every text the watcher has shown, in order.
  property var watched: []
  // The ticker's value a second into the case that waits with the menu closed.
  property string ticked: ""

  Suite {
    id: suite

    cases: [
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
        name: "a plugin that fails to load is left out",
        until: () => Plugins.get("broken") === null && Plugins.get("lastLine") !== null
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
          if (suite.waited === 1000) root.ticked = Plugins.get("ticker")?.text ?? "";
          return suite.waited >= 3000 && Plugins.get("ticker")?.text === root.ticked;
        }
      },
      {
        name: "a read with every reads again while the menu is open",
        start: () => Plugins.menuOpen = true,
        until: () => Number(Plugins.get("ticker")?.text) >= Number(root.ticked) + 2
      },
      {
        name: "tasks list by due, undated last, done ones in place, a late one in warning; the status counts the open ones due by today, warning when one is late, and names the most urgent as a field",
        start: () => root.tasks("write"),
        until: () => {
          const tasks = Plugins.get("tasks");
          const ticked = (tasks?.items ?? []).find(item => item.id === "e");
          return tasks.items.map(item => item.id).join() === "a,e,f,b,c,d" && tasks.text === "" && tasks.fields.title === "Late" && tasks.detail === "3"
            && tasks.tone === "warning" && ticked.done && ticked.icon === Glyphs.checkboxChecked
            && tasks.items.map(item => item.tone).join() === "warning,,,,,";
        }
      },
      {
        name: "picking an open task ticks it off, then syncs",
        start: () => Plugins.get("tasks").select("c"),
        until: () => Plugins.get("tasks").items.find(item => item.id === "c").done && Plugins.get("synced")?.text === "synced"
      },
      {
        name: "picking a done task unticks it",
        start: () => Plugins.get("tasks").select("e"),
        until: () => !Plugins.get("tasks").items.find(item => item.id === "e").done
      },
      {
        name: "a timed task reminds as it falls due",
        start: () => Plugins.get("tasks").remind(),
        until: () => (Plugins.get("reminded")?.text ?? "").startsWith("Now ")
      },
      {
        name: "opening the menu leaves a fresh tasks file alone",
        start: () => {
          root.tasks("unsync");
          Plugins.get("tasks").refresh();
        },
        until: () => suite.waited >= 1000 && !Plugins.get("synced")?.text
      },
      {
        name: "opening the menu syncs a tasks file five minutes old",
        start: () => root.tasks("write", "2026-01-01T00:00"),
        until: () => {
          if (Plugins.get("tasks").state.updated === "2026-01-01T00:00") Plugins.get("tasks").refresh();
          return Plugins.get("synced")?.text === "synced";
        }
      },
      {
        name: "the count stops at 9+",
        start: () => root.tasks("many"),
        until: () => Plugins.get("tasks").detail === "9+"
      }
    ]
  }

  function tasks(...args) {
    Quickshell.execDetached(["sh", Quickshell.env("XDG_CONFIG_HOME") + "/quick-key/tasks.sh", ...args]);
  }

  Connections {
    target: Plugins.get("watcher")
    function onTextChanged() {
      root.watched = root.watched.concat([target.text]);
    }
  }
}
