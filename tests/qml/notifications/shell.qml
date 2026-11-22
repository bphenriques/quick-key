import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui

// The notifications plugin on a session bus of its own, sent to with notify-send, as an app would.
ShellRoot {
  id: root

  readonly property var plugin: Plugins.get("notifications")
  property var marks: ({})
  property string waited: ""
  property string replaced: ""
  property string owner: ""

  function send(...args) {
    Quickshell.execDetached(["notify-send", ...args]);
  }

  function find(summary) {
    return plugin?.ordered.find(notification => notification.summary === summary) ?? null;
  }

  // When a case first saw something, for one that must last or go.
  function mark(key) {
    if (!(key in marks)) marks = Object.assign({}, marks, { [key]: Date.now() });
    return Date.now() - marks[key];
  }

  Process {
    id: waiting
    command: ["notify-send", "--wait", "-A", "default=Open", "-A", "later=Later", "Act"]
    stdout: StdioCollector {
      onStreamFinished: root.waited = text.trim()
    }
  }

  Process {
    id: first
    command: ["notify-send", "-p", "Count 1"]
    stdout: StdioCollector {
      onStreamFinished: root.replaced = text.trim()
    }
  }

  Suite {
    cases: [
      {
        name: "the plugin loads as the config does",
        until: () => root.plugin !== null
      },
      {
        name: "another process holding the bus shows as its error",
        start: () => {
          root.owner = root.plugin.settings.owner;
          root.plugin.settings.owner = "echo u 1";
          root.plugin.check();
        },
        until: () => root.plugin.error === root.plugin.words.taken
      },
      {
        name: "the server holds it, so no error",
        start: () => {
          root.plugin.settings.owner = root.owner;
          root.plugin.check();
        },
        until: () => root.plugin.error === ""
      },
      {
        name: "a notification shows as a card",
        start: () => root.send("-a", "App", "Hello", "World"),
        until: () => root.find("Hello")?.body === "World" && root.find("Hello").appName === "App" && root.plugin.shown.length === 1
      },
      {
        name: "its sender's timeout expires it",
        start: () => root.send("-t", "300", "Brief"),
        until: () => {
          if (root.find("Brief")) root.mark("brief");
          return "brief" in root.marks && !root.find("Brief");
        }
      },
      {
        name: "the pointer on its card holds its timer",
        start: () => root.send("-t", "300", "Held"),
        until: () => {
          const held = root.find("Held");
          if (held && !("held" in root.marks)) root.plugin.hold(held, true);
          return held !== null && root.mark("held") > 1000;
        }
      },
      {
        name: "and letting go starts it again",
        start: () => root.plugin.hold(root.find("Held"), false),
        until: () => !root.find("Held")
      },
      {
        name: "a critical one never expires and comes first",
        start: () => {
          root.send("-u", "critical", "-t", "300", "Alarm");
          root.send("Later");
        },
        until: () => root.plugin.ordered[0]?.summary === "Alarm" && root.find("Later") !== null && root.mark("alarm") > 1000
      },
      {
        name: "past the limit, the rest wait, counted",
        start: () => ["One", "Two", "Three"].forEach(summary => root.send(summary)),
        until: () => root.plugin.ordered.length === 6 && root.plugin.shown.length === 3 && root.plugin.shown[0].summary === "Alarm" && root.plugin.more === 3
      },
      {
        name: "paused, only critical ones show; the rest are held, counted, and the bell is struck and lit",
        start: () => Kept.set("notifications.paused", true),
        until: () => root.plugin.shown.length === 1 && root.plugin.shown[0].summary === "Alarm" && root.plugin.held === 5 && root.plugin.active && root.plugin.glyph === Glyphs.notificationsPaused
      },
      {
        name: "clearing dismisses every one, and the bar's action resumes",
        start: () => {
          root.plugin.actions.clear.run();
          root.plugin.actions.pause.run();
        },
        until: () => root.plugin.ordered.length === 0 && !root.plugin.paused && root.plugin.text === ""
      },
      {
        name: "a rule hides what it matches",
        start: () => {
          root.send("-a", "hidden", "Secret");
          root.send("-a", "shown", "Public");
        },
        until: () => root.find("Public") !== null && !root.find("Secret") && root.mark("hidden") > 500
      },
      {
        name: "a replacement by id updates its card",
        start: () => first.running = true,
        until: () => {
          if (root.replaced && !("replace" in root.marks)) {
            root.mark("replace");
            root.send("-r", root.replaced, "Count 2");
          }
          return root.find("Count 2") !== null && !root.find("Count 1");
        }
      },
      {
        name: "a replacement by tag, as volume tools send, keeps one card",
        start: () => root.send("-h", "string:x-dunst-stack-tag:volume", "-h", "int:value:10", "Volume"),
        until: () => {
          if (root.find("Volume")?.hints.value === 10 && !("volume" in root.marks)) {
            root.mark("volume");
            root.send("-h", "string:x-dunst-stack-tag:volume", "-h", "int:value:20", "Volume");
          }
          return root.plugin.ordered.filter(notification => notification.summary === "Volume").length === 1 && root.find("Volume").hints.value === 20;
        }
      },
      {
        name: "opening it invokes its default action, which its sender hears",
        start: () => waiting.running = true,
        until: () => {
          const act = root.find("Act");
          if (act && !("act" in root.marks)) {
            root.mark("act");
            root.plugin.open(act);
          }
          return root.waited === "default";
        }
      },
      {
        name: "the newest is what a binding dismisses",
        start: () => root.plugin.actions.dismiss.run(),
        until: () => !root.find("Volume") && root.find("Count 2") !== null
      },
      {
        name: "the settings' check names what is wrong, and passes these",
        until: () => {
          const problems = root.plugin.settings.ruleProblems({ match: { nope: "x", body: "(" }, extra: 1 });
          return root.plugin.settings.problems().length === 0 && problems.length === 3 && problems.some(problem => problem.startsWith("matches body with '('"));
        }
      }
    ]
  }
}
