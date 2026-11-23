import QtQuick
import Quickshell
import qs
import qs.builtins
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
  property bool missedRead: false

  CommandProcess {
    id: complainer
    command: ["sh", "-c", "echo bad >&2; exit 3"]
  }

  Suite {
    id: suite

    cases: [
      {
        name: "a watch that ends takes its work with it, and leaves its result to be seen, as Rex has it",
        until: () => Plugins.get("finisher")?.phase === "done" && Plugins.get("finisher").text === "built" && !Plugins.get("finisher").busy
          && Plugins.get("worker")?.phase === "idle" && Plugins.get("worker").text === ""
      },
      {
        name: "a phase or kind it does not know is idle and none",
        until: () => Plugins.get("later")?.phase === "idle" && Plugins.get("later").kind === "" && !Plugins.get("later").busy
      },
      {
        name: "with its daemon on the bus, power profiles are offered: the ones the machine has, the one in use lit",
        until: () => Power.profilesPresent && Power.profiles.join() === "power-saver,balanced" && Power.profile === "balanced" && Actions.builtin.powerProfile.available()
          && Lists.items("powerProfiles").map(item => item.desc + (item.active ? "*" : "")).join() === "Power saver,Balanced*"
      },
      {
        name: "a battery warns as its charge falls to low or critical, once each, and never as it rises; plugging in or out is its pop-up's change",
        until: () => Power.warns("normal", "low") === "low" && Power.warns("low", "critical") === "critical" && Power.warns("normal", "critical") === "critical"
          && Power.warns("critical", "low") === "" && Power.warns("low", "normal") === "" && Power.warns("low", "low") === "" && typeof Statuses.builtin.battery.change === "function"
      },
      {
        name: "a command that fails keeps its last word on stderr, which it logs",
        start: () => complainer.running = true,
        until: () => !complainer.running && complainer.complaint === "bad"
      },
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
        start: () => Quickshell.execDetached(["sh", "-c", "echo '{\"value\":\"/walls/sunset.jpg\",\"text\":\"sunset\"}' > \"$XDG_RUNTIME_DIR/wallpaper\""]),
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
        start: () => Panels.open(root),
        until: () => Number(Plugins.get("ticker")?.text) >= Number(root.ticked) + 2
      },
      {
        name: "tasks list by due, undated last, done ones in place until the menu opens, a late one in warning with an alarm, a priority as its glyph and a list's colour as a swatch; the status counts the late ones when there are any, else the open ones due by today, and names the most urgent as a field",
        start: () => root.tasks("write"),
        until: () => {
          const tasks = Plugins.get("tasks");
          const item = id => (tasks?.items ?? []).find(item => item.id === id);
          return tasks.items.map(item => item.id).join() === "a,e,f,b,c,d" && tasks.text === "" && tasks.fields.title === "Late" && tasks.detail === "1"
            && tasks.tone === "warning" && item("e").done && item("e").icon === Glyphs.checkboxChecked
            && ["a", "e", "f", "c", "d"].map(id => item(id).tone).join() === "warning,,,," && item("e").glyphs.length === 0
            && JSON.stringify(item("a").glyphs) === JSON.stringify([Glyphs.priorities.medium, Glyphs.late]) && item("b").glyphs[0] === Glyphs.priorities.high
            && item("a").swatch === "#4285f4" && item("d").swatch === "";
        }
      },
      {
        name: "a timed task is late once its minute has passed, today too; one due today without a time only from tomorrow",
        until: () => {
          const tasks = Plugins.get("tasks");
          const minuteAgo = Clock.minuteKey(new Date(Clock.date.getTime() - 60000));
          return tasks.isLate({ due: minuteAgo }) && !tasks.isLate({ due: tasks.now }) && !tasks.isLate({ due: tasks.today }) && !tasks.isLate({ due: minuteAgo, done: true });
        }
      },
      {
        name: "a task done as the menu opens is hidden for the visit, off the rows and still in the list, after the open ones",
        start: () => Plugins.get("tasks").refresh(),
        until: () => Plugins.get("tasks").items.find(item => item.id === "e").hidden && !Plugins.get("tasks").items.find(item => item.id === "a").hidden
          && Plugins.get("tasks").items.map(item => item.id).join() === "a,f,b,c,d,e"
      },
      {
        name: "the sort action steps through due, priority (none last), title and list, then due again, the done ones last under each, the one in use its value; completed through hidden, shown and only the done ones, each with when it was done",
        until: () => {
          const tasks = Plugins.get("tasks");
          Kept.set("tasks.sort", "due");
          Kept.set("tasks.completed", "hidden");
          const ids = () => tasks.items.map(item => item.id).join();
          const shown = () => tasks.items.filter(item => !item.hidden).map(item => item.id).join();
          const sorts = [];
          for (let i = 0; i < 4; i++) {
            tasks.actions.sort.run();
            sorts.push(tasks.actions.sort.detail() + " " + ids() + " " + tasks.fields.title);
          }
          const shows = [];
          const details = [];
          for (let i = 0; i < 3; i++) {
            tasks.actions.completed.run();
            shows.push(tasks.completed + " " + shown());
            details.push(tasks.items.find(item => item.id === "e").detail);
          }
          return sorts.join() === "by priority b,a,f,c,d,e Late,by title a,c,b,f,d,e Late,by list f,b,d,a,c,e Late,by due date a,f,b,c,d,e Late"
            && shows.join() === "shown a,f,b,c,d,e,only e,hidden a,f,b,c,d" && details.join() === "yesterday," + Clock.time(new Date(2000, 0, 1, 9, 0)) + ",yesterday"
            && tasks.actions.completed.icon() === Glyphs.completed.hidden && tasks.actions.sort.icon() === Glyphs.sorts.due;
        }
      },
      {
        name: "picking an open task ticks it off, then syncs, and it stays to untick",
        start: () => Plugins.get("tasks").select("c"),
        until: () => Plugins.get("tasks").items.find(item => item.id === "c").done && !Plugins.get("tasks").items.find(item => item.id === "c").hidden && Plugins.get("tasks").items.find(item => item.id === "c").verb === "untick" && Plugins.get("synced")?.text === "synced"
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
        name: "an added task shows at once in the input, as a working turn, no row moving, before its command has written the file, its after waiting for it",
        start: () => Plugins.get("tasks").submit("New", false, "echo added > \"$XDG_RUNTIME_DIR/added\""),
        until: () => Plugins.get("tasks").turn?.question === "New" && Plugins.get("tasks").turn?.phase === "working" && !Plugins.get("tasks").items.some(item => item.label === "New")
          && !Array.from(Plugins.get("tasks").state.tasks).some(task => task.title === "New")
          && Plugins.get("added")?.text !== "added"
      },
      {
        name: "once the file has it, it runs like the rest, and its after has run",
        until: () => Plugins.get("tasks").turn === null && Plugins.get("tasks").items.some(item => item.label === "New") && Plugins.get("tasks").adding.length === 0 && Plugins.get("added")?.text === "added"
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
          // Its own write landed too, so none of it runs on into the next case's file.
          return tasks.tasks.some(task => task.id === "b" && task.due === minute) && (Plugins.get("reminded")?.text ?? "").startsWith("Now ");
        }
      },
      {
        name: "a first check, with none fired yet, skips what fell due before it and keeps it as fired",
        start: () => root.tasks("missed"),
        until: () => {
          // Cleared once the file has it, so a check between never sees the last test's task, due this minute, as a first.
          if (!Plugins.get("tasks").tasks.some(task => task.id === "m")) return false;
          if (!root.missedRead) {
            root.missedRead = true;
            Kept.set("tasks.reminded", undefined);
            root.tasks("unremind");
            Plugins.get("tasks").remind();
          }
          return suite.waited >= 1000 && !Plugins.get("reminded")?.text && Array.from(Kept.value("tasks.reminded") ?? []).some(key => key.startsWith("Missed "));
        }
      },
      {
        name: "a reminder that fell due unseen (a suspend, the shell off) fires as the next check comes, its time as the clock says it",
        start: () => {
          Kept.set("tasks.reminded", []);
          Plugins.get("tasks").remind();
        },
        until: () => Plugins.get("reminded")?.text === "Missed " + Clock.time(Clock.parse(Plugins.get("tasks").state.tasks[0].due))
      },
      {
        name: "and only once",
        start: () => {
          root.tasks("unremind");
          Plugins.get("tasks").remind();
        },
        until: () => suite.waited >= 1000 && !Plugins.get("reminded")?.text
      },
      {
        name: "a tick whose command succeeds but the file never says so shows the file's state again",
        start: () => {
          root.tasks("stick");
          Plugins.get("tasks").select("m");
        },
        until: () => suite.waited >= 5000 && !Plugins.get("tasks").items.find(item => item.id === "m").done && Object.keys(Plugins.get("tasks").pending).length === 0,
        timeout: 8000
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
      },
      {
        name: "a theme file sets the bubble colour",
        until: () => Qt.colorEqual(Config.colors.bubble, "#123456")
      },
      {
        name: "any plugin takes a title, else its name",
        until: () => Plugins.get("lastLine").title === "Last" && Plugins.get("watcher").title === "watcher"
      },
      {
        name: "any plugin takes a glyph",
        until: () => Plugins.get("watcher").glyph === "W"
      },
      {
        name: "any plugin runs its activate",
        start: () => Plugins.get("lastLine").activate(),
        until: () => Plugins.get("activated")?.text === "on"
      },
      {
        name: "a click on a plugin read on demand reads it again once its command ends",
        start: () => Plugins.get("clicked").activate(),
        until: () => Plugins.get("clicked").text === "yes"
      },
      {
        name: "a choice made while another runs is not dropped",
        start: () => {
          Plugins.get("chooser").select("a");
          Plugins.get("chooser").select("b");
          Plugins.get("chooser").select("c");
        },
        until: () => Plugins.get("choseA").text === "picked" && Plugins.get("choseB").text === "picked" && Plugins.get("choseC").text === "picked"
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
