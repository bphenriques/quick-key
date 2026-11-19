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
  // How often the plugin whose watch repeats its line changed state.
  property int repeats: 0
  // The minute the timed task was last written as due.
  property string dueMinute: ""

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
        name: "a line the same as the last changes nothing",
        until: () => suite.waited >= 1000 && Plugins.get("repeated")?.text === "same" && root.repeats === 1
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
        name: "tasks list by due, undated last, done ones in place, a late one in warning with an alarm; the status counts the late ones when there are any, else the open ones due by today, and names the most urgent as a field",
        start: () => root.tasks("write"),
        until: () => {
          const tasks = Plugins.get("tasks");
          const ticked = (tasks?.items ?? []).find(item => item.id === "e");
          return tasks.items.map(item => item.id).join() === "a,e,f,b,c,d" && tasks.text === "" && tasks.fields.title === "Late" && tasks.detail === "1"
            && tasks.tone === "warning" && ticked.done && ticked.icon === Glyphs.checkboxChecked
            && tasks.items.map(item => item.tone).join() === "warning,,,,," && tasks.items[0].glyphs[0] === Glyphs.late && tasks.items[1].glyphs.length === 0;
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
        name: "a tick shows at once, before its command has written the file",
        start: () => Plugins.get("tasks").select("f"),
        until: () => Plugins.get("tasks").items.find(item => item.id === "f").done
          && !Array.from(Plugins.get("tasks").state.tasks).find(task => task.id === "f").done
      },
      {
        name: "a tick whose command fails shows the file's state again, and says which failed",
        start: () => Plugins.get("tasks").select("d"),
        until: () => !Plugins.get("tasks").items.find(item => item.id === "d").done && Plugins.get("tasks").queue.length === 0
          && Object.keys(Plugins.get("tasks").pending).length === 0 && Plugins.get("tasks").error === "Could not tick off Undated"
      },
      {
        name: "an added task shows at once, dim with a spinner, before its command has written the file, its after waiting for it",
        start: () => Plugins.get("tasks").submit("New", false, "echo added > \"$XDG_RUNTIME_DIR/added\""),
        until: () => Plugins.get("tasks").items.some(item => item.label === "New" && item.enabled === false && item.busy)
          && !Array.from(Plugins.get("tasks").state.tasks).some(task => task.title === "New")
          && Plugins.get("added")?.text !== "added"
      },
      {
        name: "once the file has it, it runs like the rest, and its after has run",
        until: () => Plugins.get("tasks").items.some(item => item.label === "New" && item.enabled) && Plugins.get("tasks").adding.length === 0 && Plugins.get("added")?.text === "added"
      },
      {
        name: "an add whose command fails drops it, says so, and skips its after",
        start: () => Plugins.get("tasks").submit("Fail", false, "echo wrong > \"$XDG_RUNTIME_DIR/added\""),
        until: () => !Plugins.get("tasks").items.some(item => item.label === "Fail") && Plugins.get("tasks").queue.length === 0
          && Plugins.get("tasks").error === "Could not add Fail" && Plugins.get("added")?.text === "added"
      },
      {
        name: "a timed task reminds as it falls due",
        // Due this minute only for a minute: written again as the case starts, and again should the minute turn before it is read.
        until: () => {
          const minute = Qt.formatDateTime(Clock.date, "yyyy-MM-ddTHH:mm");
          const tasks = Plugins.get("tasks");
          if (tasks.tasks.some(task => task.id === "b" && task.due === minute)) tasks.remind();
          else if (root.dueMinute !== minute) {
            root.dueMinute = minute;
            root.tasks("write");
          }
          return (Plugins.get("reminded")?.text ?? "").startsWith("Now ");
        }
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
      },
      {
        name: "a sync that failed is the plugin's error, for its level to show",
        start: () => root.tasks("broken"),
        until: () => Plugins.get("tasks").error.endsWith("personal: could not sync")
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

  Connections {
    target: Plugins.get("repeated")
    function onStateChanged() {
      root.repeats++;
    }
  }
}
