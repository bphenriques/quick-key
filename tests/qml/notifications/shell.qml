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
  property string chosen: ""
  property string onceId: ""
  property string codeDesc: ""

  Process {
    id: once
    command: ["notify-send", "-p", "-a", "runner", "Run once"]
    stdout: StdioCollector {
      onStreamFinished: root.onceId = text.trim()
    }
  }
  property var replies: []
  property string chat: ""
  property string files: ""

  function readFiles() {
    files = "";
    reader.running = true;
  }

  // What the rules' commands wrote, and whether a notification's text ran anything.
  Process {
    id: reader
    command: ["sh", "-c", "cd \"$XDG_RUNTIME_DIR\" && for f in ran arrived opened edited forked pwned; do [ -e $f ] && echo \"$f: $(cat $f)\"; done; true"]
    stdout: StdioCollector {
      onStreamFinished: root.files = text
    }
  }

  function chatSend(summary, hints = "@a{sv} {}") {
    Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "'Chat'", "uint32 0", "''", "'" + summary + "'", "'Lunch?'", "['inline-reply', 'Reply']", hints, "int32 -1"]);
  }

  // What the bus says the server sent its senders: their replies.
  Process {
    running: true
    command: ["gdbus", "monitor", "--session", "--dest", "org.freedesktop.Notifications"]
    stdout: SplitParser {
      onRead: line => {
        if (line.includes("NotificationReplied")) root.replies = root.replies.concat([line]);
      }
    }
  }

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
    id: chooser
    command: ["notify-send", "--wait", "-A", "default=Open", "-A", "later=Later", "-A", "next=Next week", "Choose"]
    stdout: StdioCollector {
      onStreamFinished: root.chosen = text.trim()
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
          if (held && !("held" in root.marks)) root.plugin.hold(true);
          return held !== null && root.mark("held") > 1000;
        }
      },
      {
        name: "and letting go starts it again",
        start: () => root.plugin.hold(false),
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
        name: "a rule matches a sender's category",
        start: () => {
          root.send("-c", "filed", "Filed");
          root.send("-c", "other", "Unfiled");
        },
        until: () => root.find("Unfiled") !== null && !root.find("Filed") && root.mark("filed") > 500
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
        name: "summoned, the cards take the keys, the newest picked, every held one shown, and their time holds",
        start: () => {
          root.plugin.clear();
          Kept.set("notifications.paused", true);
          root.send("-t", "400", "Quick");
        },
        until: () => {
          if (root.find("Quick") && !("quick" in root.marks)) {
            root.mark("quick");
            root.send("Second");
          }
          if (root.find("Second") && !root.plugin.summoned) root.plugin.actions.summon.run();
          return root.plugin.summoned && root.plugin.picked?.summary === "Second" && root.plugin.shown.length === 2 && root.mark("summoned") > 1000 && root.find("Quick") !== null;
        }
      },
      {
        name: "summoned, one that comes goes last, so digits hold; a digit and the arrows pick",
        start: () => chooser.running = true,
        until: () => {
          if (root.find("Choose") && !("choose" in root.marks)) {
            root.mark("choose");
            root.plugin.key("1");
            root.plugin.key("Down");
            root.plugin.key("Down");
          }
          return root.plugin.shown.map(notification => notification.summary).join() === "Second,Quick,Choose" && root.plugin.picked?.summary === "Choose";
        }
      },
      {
        name: "the picked card's actions take letters from their labels, never x, and a letter runs one, which its sender hears",
        start: () => root.plugin.key(root.plugin.actionsOf(root.plugin.picked).find(action => action.desc === "Later").key),
        until: () => root.chosen === "later"
          && MenuKeys.assign(["Open", "Other"], ["x"], "").join() === "o,t" && MenuKeys.assign(["x"], ["x"], "").join() === ""
      },
      {
        name: "x dismisses the picked card, the pick moving to the one in its place",
        start: () => {
          root.plugin.key("1");
          root.plugin.key("x");
        },
        until: () => !root.find("Second") && root.plugin.picked?.summary === "Quick"
      },
      {
        name: "a key path runs as typing it would, and ESC lets go of the keys, the held ones held again",
        start: () => {
          root.send("Third");
          root.plugin.press("Escape");
        },
        until: () => !root.plugin.summoned && root.plugin.held >= 1 && root.plugin.shown.length === 0
      },
      {
        name: "RET opens the picked card, dismissing one without a default action, and lets go",
        start: () => {
          Kept.set("notifications.paused", false);
          root.plugin.press("1 Return");
        },
        until: () => !root.plugin.summoned && !root.find("Third")
      },
      {
        name: "a sender offering a reply gets it first among the card's actions, on TAB",
        start: () => root.chatSend("Ana"),
        until: () => root.find("Ana")?.hasInlineReply && root.plugin.actionsOf(root.find("Ana"))[0]?.key === "Tab"
      },
      {
        name: "TAB opens the prompt in the card, and a reply sent reaches its sender, which closes it as an action does, and the keys go back",
        start: () => {
          root.plugin.reply(root.find("Ana"));
          root.plugin.sendReply("Yes, at one", false);
        },
        until: () => root.replies.some(line => line.includes("Yes, at one")) && !root.find("Ana") && root.plugin.replying === null && !root.plugin.summoned
      },
      {
        name: "a resident one stays, showing what was sent in its actions' place, the keys staying",
        start: () => root.chatSend("Cid", "@a{sv} {'resident': <true>}"),
        until: () => {
          const cid = root.find("Cid");
          if (cid && !("cid" in root.marks)) {
            root.mark("cid");
            root.plugin.reply(cid);
            root.plugin.sendReply("On my way", false);
          }
          return root.replies.some(line => line.includes("On my way")) && root.plugin.sent[root.find("Cid")?.id] === "On my way" && root.plugin.summoned && root.plugin.actionsOf(root.find("Cid")).length === 0;
        }
      },
      {
        name: "one closed while replied to stays as a placeholder, its text unsent, until the reply ends",
        start: () => {
          root.plugin.release();
          root.chatSend("Bea");
        },
        until: () => {
          const bea = root.find("Bea");
          if (bea && !("bea" in root.marks)) {
            root.mark("bea");
            root.plugin.reply(bea);
            bea.dismiss();
          }
          return root.plugin.replying?.gone === true && root.find("Bea")?.gone === true && !root.plugin.sendReply("Too late", false);
        }
      },
      {
        name: "and ending it lets the placeholder go",
        start: () => root.plugin.endReply(),
        until: () => !root.find("Bea") && root.plugin.replying === null
      },
      {
        name: "a rule sets the urgency, so its card is critical, first and never expiring",
        start: () => {
          root.plugin.release();
          Kept.set("notifications.paused", false);
          root.plugin.clear();
          root.send("-a", "urgent", "-t", "300", "Urgent");
        },
        until: () => root.find("Urgent") !== null && root.plugin.critical(root.find("Urgent")) && root.plugin.ordered[0]?.summary === "Urgent" && root.mark("urgent") > 1000
      },
      {
        name: "a rule sets the time it shows, over its sender's: briefer, or never",
        start: () => {
          root.send("-a", "brief", "Brief rule");
          root.send("-a", "sticky", "-t", "300", "Sticky");
        },
        until: () => {
          if (root.find("Brief rule")) root.mark("briefRule");
          return "briefRule" in root.marks && !root.find("Brief rule") && root.find("Sticky") !== null && root.mark("sticky") > 1000;
        }
      },
      {
        name: "a rule lets one through a pause, which holds the rest",
        start: () => {
          Kept.set("notifications.paused", true);
          root.send("-a", "loud", "Loud");
          root.send("-a", "quiet", "Quiet");
        },
        until: () => root.plugin.shown.some(notification => notification.summary === "Loud") && root.find("Quiet") !== null && !root.plugin.shown.some(notification => notification.summary === "Quiet")
      },
      {
        name: "a rule adds its own action on its key, its label and command given what its groups found, and running it closes its card",
        start: () => {
          root.plugin.release();
          Kept.set("notifications.paused", false);
          root.send("-a", "Bank", "Code", "Your code is 482913.");
        },
        until: () => {
          const action = root.plugin.actionsOf(root.find("Code")).find(action => action.key === "c");
          if (action && !("code" in root.marks)) {
            root.mark("code");
            root.codeDesc = action.desc;
            action.run();
          }
          if ("code" in root.marks && root.mark("code") > 500 && !root.files) root.readFiles();
          return root.codeDesc === "Copy 482913" && root.files.includes("ran: 482913 Bank") && !root.find("Code");
        }
      },
      {
        name: "a rule runs a command as one arrives, its text given, never run",
        start: () => {
          root.files = "";
          root.send("-a", "runner", "$(touch $XDG_RUNTIME_DIR/pwned); true", "body");
        },
        until: () => {
          if (root.find("$(touch $XDG_RUNTIME_DIR/pwned); true") && root.mark("runner") > 500 && !root.files) root.readFiles();
          return root.files.includes("arrived: $(touch $XDG_RUNTIME_DIR/pwned); true") && !root.files.includes("pwned:");
        }
      },
      {
        name: "a rule's default is what opening it runs, and it is done with",
        start: () => {
          root.files = "";
          root.send("-a", "opener", "Open me");
        },
        until: () => {
          const card = root.find("Open me");
          if (card && !("opener" in root.marks)) {
            root.mark("opener");
            root.plugin.open(card);
          }
          if ("opener" in root.marks && root.mark("opener") > 500 && !root.files) root.readFiles();
          return root.files.includes("opened: opened") && !root.find("Open me");
        }
      },
      {
        name: "a rule's command gets its picture as a file, as niri sends a screenshot, and closes its card when the action says so",
        start: () => {
          root.files = "";
          Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "'shooter'", "uint32 0", "'file:///tmp/My%20Shot.png'", "'Screenshot captured'", "'You can paste the image from the clipboard.'", "@as []", "@a{sv} {}", "int32 -1"]);
        },
        until: () => {
          const shot = root.find("Screenshot captured");
          const edit = root.plugin.actionsOf(shot).find(action => action.key === "e");
          if (edit && !("shot" in root.marks)) {
            root.mark("shot");
            edit.run();
          }
          if ("shot" in root.marks && root.mark("shot") > 500 && !root.files) root.readFiles();
          return root.files.includes("edited: /tmp/My Shot.png") && !root.find("Screenshot captured");
        }
      },
      {
        name: "a sender's time is in milliseconds, so five seconds last past one",
        start: () => {
          root.plugin.release();
          Kept.set("notifications.paused", false);
          root.plugin.clear();
          root.send("-t", "5000", "Long");
        },
        until: () => root.find("Long") !== null && root.mark("long") > 1200
      },
      {
        name: "the pointer on any card holds every one still, one that comes meanwhile going last",
        start: () => root.plugin.hold(true),
        until: () => {
          if (!("after" in root.marks)) {
            root.mark("after");
            root.send("After");
          }
          return root.plugin.ordered.map(notification => notification.summary).join() === "Long,After" && root.plugin.still;
        }
      },
      {
        name: "and letting go puts the newest first again",
        start: () => root.plugin.hold(false),
        until: () => root.plugin.ordered.map(notification => notification.summary).join() === "After,Long"
      },
      {
        name: "a reply's draft is its own card's",
        until: () => {
          root.plugin.keepDraft({ id: 9991 }, "for one");
          return root.plugin.draftOf({ id: 9991 }) === "for one" && root.plugin.draftOf({ id: 9992 }) === "";
        }
      },
      {
        name: "summoned, limit cards show, the arrows scrolling past them, Down toward a bottom corner",
        start: () => ["C", "D", "E"].forEach(summary => root.send(summary)),
        until: () => {
          if (root.plugin.ordered.length === 5 && !root.plugin.summoned) {
            root.plugin.settings.corner = "bottom-right";
            root.plugin.summon();
            root.plugin.key("Up");
            root.plugin.key("Up");
            root.plugin.key("Up");
          }
          return root.plugin.summoned && root.plugin.shown.length === 3 && root.plugin.range === "2-4 of 5" && root.plugin.picked === root.plugin.shown[2];
        }
      },
      {
        name: "and Down goes back toward the corner",
        start: () => root.plugin.key("Down"),
        until: () => root.plugin.picked === root.plugin.shown[1] && root.plugin.range === "2-4 of 5"
      },
      {
        name: "a digit is a card's place among all, so it holds still, and picking one scrolls it into view",
        start: () => root.plugin.key("1"),
        until: () => root.plugin.picked === root.plugin.showable[0] && root.plugin.range === "1-3 of 5" && root.plugin.shown[0] === root.plugin.showable[0]
      },
      {
        name: "a critical card stays by the corner while the rest scroll",
        start: () => root.send("-u", "critical", "Alarm two"),
        until: () => {
          if (root.find("Alarm two") && !("pinned" in root.marks)) {
            root.mark("pinned");
            for (let i = 0; i < 6; i++) root.plugin.key("Up");
          }
          return "pinned" in root.marks && root.plugin.shown[0]?.summary === "Alarm two" && root.plugin.range !== "" && !root.plugin.range.startsWith("1-");
        }
      },
      {
        name: "? lists the keys, and any key closes the list",
        start: () => root.plugin.key("?"),
        until: () => {
          const listed = root.plugin.help && root.plugin.keys.some(hint => hint.key === "Ctrl+r");
          if (listed) root.plugin.key("a");
          return listed && !root.plugin.help;
        }
      },
      {
        name: "C-r brings back the last closed, to read, never the passing ones",
        start: () => {
          root.plugin.release();
          root.plugin.settings.corner = "top-right";
          root.plugin.clear();
          root.send("Keep me");
        },
        until: () => {
          const kept = root.find("Keep me");
          if (kept && !kept.restored && !("restore" in root.marks)) {
            root.mark("restore");
            kept.dismiss();
            root.send("--transient", "Passing");
          }
          const passing = root.find("Passing");
          if (passing && !("passing" in root.marks)) {
            root.mark("passing");
            passing.dismiss();
          }
          if ("passing" in root.marks && !root.find("Passing") && !("back" in root.marks)) {
            root.mark("back");
            root.plugin.summon();
            root.plugin.key("Ctrl+r");
            root.plugin.key("Ctrl+r");
          }
          const back = root.find("Keep me");
          return back?.restored === true && !root.find("Passing") && root.plugin.actionsOf(back).length === 0;
        }
      },
      {
        name: "run runs for a new card, not again when it is replaced",
        start: () => {
          root.plugin.release();
          root.plugin.settings.corner = "top-right";
          root.files = "";
          once.running = true;
        },
        until: () => {
          if (root.onceId && !("once" in root.marks)) {
            root.mark("once");
            root.send("-a", "runner", "-r", root.onceId, "Run once");
          }
          if ("once" in root.marks && root.mark("once") > 700 && !root.files) root.readFiles();
          return root.files.split("Run once").length === 2;
        }
      },
      {
        name: "notify-send -i sends its icon as image-path: a file reaches a rule's command as one, a name stays a name",
        start: () => {
          root.files = "";
          root.send("-a", "shooter", "-i", "/tmp/Other shot.png", "Second shot");
          root.send("-i", "dialog-information", "Named icon");
        },
        until: () => {
          const shot = root.find("Second shot");
          const edit = root.plugin.actionsOf(shot).find(action => action.key === "e");
          if (edit && !("other" in root.marks)) {
            root.mark("other");
            edit.run();
          }
          if ("other" in root.marks && root.mark("other") > 500 && !root.files) root.readFiles();
          const named = root.find("Named icon");
          return root.files.includes("edited: /tmp/Other shot.png") && named !== null && root.plugin.fileOf(named) === "" && root.plugin.iconOf(named) === "dialog-information";
        }
      },
      {
        name: "what a rule's command leaves running outlives it, as wl-copy does serving the clipboard",
        start: () => {
          root.files = "";
          root.send("-a", "forker", "Fork me");
        },
        until: () => {
          const fork = root.plugin.actionsOf(root.find("Fork me")).find(action => action.key === "f");
          if (fork && !("fork" in root.marks)) {
            root.mark("fork");
            fork.run();
          }
          if ("fork" in root.marks && root.mark("fork") > 1200 && !root.files) root.readFiles();
          return root.files.includes("forked: forker");
        }
      },
      {
        name: "the settings' check names what is wrong, and passes these",
        until: () => {
          const problems = root.plugin.settings.ruleProblems({ match: { nope: "x", body: "(", summary: "(?<app>x)" }, extra: 1, timeout: -1, urgency: "loud", ignorePause: "yes", actions: [{ key: "x", desc: "D", cmd: "c" }, { key: "q", cmd: "c", closes: "yes" }], run: 1 });
          return root.plugin.settings.problems().length === 0 && problems.length === 11 && root.plugin.settings.groupNames("(a)(?:b)(?<c>[(]d)\\(").join() === ",c" && problems.some(problem => problem.startsWith("matches body with '('")) && problems.includes("sets urgency to 'loud', none of low, normal, critical");
        }
      }
    ]
  }
}
