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
    command: ["sh", "-c", "cd \"$XDG_RUNTIME_DIR\" && for f in ran arrived opened edited forked pwned ghosted; do [ -e $f ] && echo \"$f: $(cat $f)\"; done; true"]
    stdout: StdioCollector {
      onStreamFinished: root.files = text
    }
  }

  function notify(app, summary) {
    Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "'" + app + "'", "uint32 0", "''", "'" + summary + "'", "''", "['inline-reply', 'Reply']", "@a{sv} {}", "int32 -1"]);
  }

  function chatSend(summary, hints = "@a{sv} {}", replaces = 0) {
    Quickshell.execDetached(["gdbus", "call", "--session", "--dest", "org.freedesktop.Notifications", "--object-path", "/org/freedesktop/Notifications", "--method", "org.freedesktop.Notifications.Notify", "'Chat'", "uint32 " + replaces, "''", "'" + summary + "'", "'Lunch?'", "['inline-reply', 'Reply']", hints, "int32 -1"]);
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

  // Its id as notify-send prints it, by key, to replace it.
  property var ids: ({})

  function sendId(key, ...args) {
    idSender.createObject(root, { key: key, command: ["notify-send", "-p", ...args] }).running = true;
  }

  Component {
    id: idSender

    Process {
      property string key
      stdout: StdioCollector {
        onStreamFinished: root.ids = Object.assign({}, root.ids, { [key]: text.trim() })
      }
    }
  }

  // Back to no cards and no keys, for a case that counts them.
  function reset() {
    plugin.release();
    plugin.clear();
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
          root.plugin.refresh();
        },
        until: () => root.plugin.error === root.plugin.words.taken
      },
      {
        name: "the server holds it, so no error",
        start: () => {
          root.plugin.settings.owner = root.owner;
          root.plugin.refresh();
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
        name: "with no card shown taking a reply, ? lists none of the reply's keys",
        until: () => !root.plugin.shown.some(card => card.hasInlineReply) && !root.plugin.keys.some(hint => hint.key === "Tab" || hint.key === "Ctrl+Shift+Return")
      },
      {
        name: "a sender offering a reply gets it first among the card's actions, on TAB, which ? lists",
        start: () => root.chatSend("Ana"),
        until: () => root.find("Ana")?.hasInlineReply && root.plugin.actionsOf(root.find("Ana"))[0]?.key === "Tab" && root.plugin.keys.some(hint => hint.key === "Tab")
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
        name: "a resident one stays after a reply, its actions back, the keys staying",
        start: () => root.chatSend("Cid", "@a{sv} {'resident': <true>}"),
        until: () => {
          const cid = root.find("Cid");
          if (cid && !("cid" in root.marks)) {
            root.mark("cid");
            root.plugin.reply(cid);
            root.plugin.sendReply("On my way", false);
          }
          return root.replies.some(line => line.includes("On my way")) && root.find("Cid") !== null && root.plugin.summoned && root.plugin.mode === "cards" && root.plugin.actionsOf(root.find("Cid")).length > 0;
        }
      },
      {
        name: "one closed while replied to ends the reply, the text on the clipboard, and the keys do nothing until ESC",
        start: () => {
          root.plugin.release();
          root.chatSend("Bea");
        },
        until: () => {
          const bea = root.find("Bea");
          if (bea && !("bea" in root.marks)) {
            root.mark("bea");
            root.plugin.reply(bea);
            root.plugin.keepDraft(bea, "Too late");
            bea.notification.dismiss();
          }
          if (!("bea" in root.marks) || root.plugin.replying !== null || root.find("Bea") || root.plugin.mode !== "closed" || !root.plugin.copied || Quickshell.clipboardText !== "Too late") return false;
          const held = root.plugin.key("x") && root.plugin.summoned;
          root.plugin.key("Escape");
          return held && !root.plugin.summoned && root.plugin.mode === "cards";
        }
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
          return root.plugin.summoned && root.plugin.shown.length === 3 && root.plugin.more === 2 && root.plugin.shown[0] === root.plugin.showable[1] && root.plugin.picked === root.plugin.shown[2];
        }
      },
      {
        name: "and Down goes back toward the corner",
        start: () => root.plugin.key("Down"),
        until: () => root.plugin.picked === root.plugin.shown[1] && root.plugin.shown[0] === root.plugin.showable[1]
      },
      {
        name: "a digit is a card's place among all, so it holds still, and picking one scrolls it into view",
        start: () => root.plugin.key("1"),
        until: () => root.plugin.picked === root.plugin.showable[0] && root.plugin.shown[0] === root.plugin.showable[0]
      },
      {
        name: "? lists the keys the bar does not show, and any key closes the list",
        start: () => root.plugin.key("?"),
        until: () => {
          const listed = root.plugin.mode === "help" && root.plugin.keys.some(hint => hint.key === "Ctrl+r" && hint.desc) && !root.plugin.keys.some(hint => hint.key === "Ctrl+p" && hint.desc);
          if (listed) root.plugin.key("a");
          return listed && root.plugin.mode === "cards";
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
            root.plugin.dismiss(kept);
            root.send("--transient", "Passing");
          }
          const passing = root.find("Passing");
          if (passing && !("passing" in root.marks)) {
            root.mark("passing");
            root.plugin.dismiss(passing);
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
        name: "however the keys go, the menu taking them included, a reply ends",
        start: () => root.chatSend("Dee"),
        until: () => {
          const dee = root.find("Dee");
          if (dee && !("dee" in root.marks)) {
            root.mark("dee");
            root.plugin.reply(dee);
            Panels.close();
          }
          return "dee" in root.marks && root.plugin.replying === null && !root.plugin.summoned;
        }
      },
      {
        name: "a replacement by id starts its time again",
        start: () => {
          root.reset();
          root.sendId("prog", "-t", "1500", "Prog 1");
        },
        until: () => {
          if (root.ids.prog && !("prog" in root.marks)) root.mark("prog");
          if ("prog" in root.marks && root.mark("prog") > 1000 && !("prog2" in root.marks)) {
            root.mark("prog2");
            root.send("-r", root.ids.prog, "-t", "1500", "Prog 2");
          }
          return "prog" in root.marks && root.mark("prog") > 2300 && root.find("Prog 2") !== null;
        }
      },
      {
        name: "and reads its rules again: what their groups find, and a critical urgency that never expires",
        start: () => root.sendId("code", "-t", "800", "Code A", "code 111111"),
        until: () => {
          if (root.ids.code && !("codeAgain" in root.marks)) {
            root.mark("codeAgain");
            root.send("-r", root.ids.code, "-u", "critical", "Code B", "code 222222");
          }
          const code = root.find("Code B");
          return "codeAgain" in root.marks && root.mark("codeAgain") > 1600 && code !== null && root.plugin.critical(code) && root.plugin.actionsOf(code).some(action => action.desc === "Copy 222222");
        }
      },
      {
        name: "a replacement by tag takes the pick, the keys staying, and is nothing to bring back",
        start: () => {
          root.reset();
          root.send("-h", "string:x-dunst-stack-tag:vol", "-h", "int:value:10", "Vol");
        },
        until: () => {
          if (root.find("Vol")?.hints.value === 10 && !("vol" in root.marks)) {
            root.mark("vol");
            root.plugin.summon();
            root.send("-h", "string:x-dunst-stack-tag:vol", "-h", "int:value:20", "Vol");
          }
          const vol = root.find("Vol");
          if (vol?.hints.value !== 20 || !root.plugin.summoned || root.plugin.picked !== vol) return false;
          root.plugin.restore();
          return root.plugin.ordered.filter(notification => notification.summary === "Vol").length === 1;
        }
      },
      {
        name: "while replying, the keys stay with the prompt: arrows and letters act on no card",
        start: () => {
          root.reset();
          ["P1", "P2", "P3", "P4"].forEach(summary => root.send(summary));
          root.chatSend("Rex");
        },
        until: () => {
          const rex = root.find("Rex");
          if (!rex || root.plugin.ordered.length < 5) return false;
          root.plugin.reply(rex);
          ["Down", "Down", "Down", "x", "Ctrl+X"].forEach(name => root.plugin.key(name));
          return root.plugin.replying === rex && root.plugin.shown.includes(rex) && root.plugin.ordered.length === 5;
        }
      },
      {
        name: "a card brought back runs nothing when clicked, only goes",
        start: () => {
          root.reset();
          root.files = "";
          root.notify("ghostly", "Ghost");
        },
        until: () => {
          const ghost = root.find("Ghost");
          if (ghost && !ghost.restored && !("ghost" in root.marks)) {
            root.mark("ghost");
            root.plugin.dismiss(ghost);
            root.plugin.restore();
            root.plugin.open(root.find("Ghost"));
          }
          if ("ghost" in root.marks && root.mark("ghost") > 700 && !root.files) root.readFiles();
          return root.files !== "" && !root.files.includes("ghosted") && !root.find("Ghost");
        }
      },
      {
        name: "with critical ones past the limit, a digit picks what then shows",
        start: () => {
          root.reset();
          ["K1", "K2", "K3", "K4"].forEach(summary => root.send("-u", "critical", summary));
          root.send("Normal");
        },
        until: () => {
          if (root.plugin.ordered.length < 5) return false;
          root.plugin.summon();
          root.plugin.key("5");
          return root.plugin.shown.length === 3 && root.plugin.picked?.summary === "Normal" && root.plugin.shown.includes(root.plugin.picked);
        }
      },
      {
        name: "an action on a key an earlier rule took replaces it",
        start: () => {
          root.reset();
          root.send("-a", "dup", "Dup", "code 333333");
        },
        until: () => {
          const actions = root.plugin.actionsOf(root.find("Dup"));
          return actions.length === 1 && actions[0].key === "c" && actions[0].desc === "Call";
        }
      },
      {
        name: "a card a sent reply closes can be brought back",
        start: () => {
          root.reset();
          root.chatSend("Zed");
        },
        until: () => {
          const zed = root.find("Zed");
          if (zed && !("zed" in root.marks)) {
            root.mark("zed");
            root.plugin.reply(zed);
            root.plugin.sendReply("Yes", false);
          }
          if ("zed" in root.marks && !root.find("Zed") && !("zedBack" in root.marks)) {
            root.mark("zedBack");
            root.plugin.restore();
          }
          return root.find("Zed")?.restored === true;
        }
      },
      {
        name: "a restored critical card stays",
        start: () => {
          root.reset();
          root.plugin.settings.timeout = ({ low: 1, normal: 1 });
          root.send("-u", "critical", "Siren");
        },
        until: () => {
          const siren = root.find("Siren");
          if (siren && !siren.restored && !("siren" in root.marks)) {
            root.mark("siren");
            root.plugin.dismiss(siren);
            root.plugin.restore();
          }
          return "siren" in root.marks && root.mark("siren") > 2000 && root.find("Siren")?.restored === true;
        }
      },
      {
        name: "past keep, the oldest but critical ones close, to bring back",
        start: () => {
          root.plugin.settings.timeout = ({ low: 1, normal: 30 });
          root.reset();
          root.send("-u", "critical", "Kept alarm");
          ["Keep 1", "Keep 2", "Keep 3"].forEach(summary => root.send(summary));
        },
        until: () => {
          if (root.plugin.ordered.length === 4 && !("keep" in root.marks)) {
            root.mark("keep");
            root.plugin.settings.keep = 3;
            root.send("Keep 4");
          }
          const done = "keep" in root.marks && root.plugin.ordered.length === 3 && root.find("Kept alarm") !== null && root.find("Keep 4") !== null;
          if (done) root.plugin.settings.keep = 100;
          return done;
        }
      },
      {
        name: "a card brought back comes in as the newest, in view",
        start: () => {
          root.reset();
          root.send("R1");
        },
        until: () => {
          const first = root.find("R1");
          if (first && !first.restored && !("r1" in root.marks)) {
            root.mark("r1");
            root.plugin.dismiss(first);
            ["R2", "R3", "R4"].forEach(summary => root.send(summary));
          }
          if (root.plugin.ordered.length === 3 && !("r1Back" in root.marks)) {
            root.mark("r1Back");
            root.plugin.restore();
          }
          return "r1Back" in root.marks && root.find("R1")?.restored === true && root.plugin.shown.includes(root.find("R1"));
        }
      },
      {
        name: "a critical card that comes while summoned goes last, the pick staying in view, and x keeps the keys",
        start: () => {
          root.reset();
          ["M1", "M2", "M3"].forEach(summary => root.send(summary));
        },
        until: () => {
          if (root.plugin.ordered.length === 3 && !("critHeld" in root.marks)) {
            root.mark("critHeld");
            root.plugin.summon();
            root.plugin.pick(root.plugin.shown[2]);
            root.send("-u", "critical", "Crit");
          }
          if (!root.find("Crit") || !("critHeld" in root.marks)) return false;
          const picked = root.plugin.picked;
          if (!root.plugin.shown.includes(picked) || root.plugin.ordered[3]?.summary !== "Crit") return false;
          root.plugin.key("x");
          return root.plugin.summoned && root.plugin.ordered.length === 3 && root.plugin.shown.includes(root.plugin.picked);
        }
      },
      {
        name: "a tag replacement while held still keeps its card's place and the pick on it",
        start: () => {
          root.reset();
          ["T1", "T2"].forEach(summary => root.send(summary));
        },
        until: () => {
          if (root.plugin.ordered.length === 2 && !("tags" in root.marks)) {
            root.mark("tags");
            root.send("-h", "string:x-dunst-stack-tag:bri", "-h", "int:value:10", "Bri");
          }
          if (root.find("Bri")?.hints.value === 10 && !("bri" in root.marks)) {
            root.mark("bri");
            root.plugin.summon();
            root.plugin.pick(root.find("Bri"));
            root.send("-h", "string:x-dunst-stack-tag:bri", "-h", "int:value:20", "Bri");
          }
          const bri = root.find("Bri");
          return bri?.hints.value === 20 && root.plugin.ordered[0] === bri && root.plugin.picked === bri;
        }
      },
      {
        name: "a card its sender replaces by id keeps its place",
        start: () => {
          root.reset();
          root.sendId("group", "Group 1");
        },
        until: () => {
          if (root.ids.group && root.find("Group 1") && !("group" in root.marks)) {
            root.mark("group");
            root.send("Other");
          }
          if (root.find("Other") && !("group2" in root.marks)) {
            root.mark("group2");
            root.send("-r", root.ids.group, "Group 2");
          }
          return root.plugin.ordered.map(each => each.summary).join() === "Other,Group 2";
        }
      },
      {
        name: "a replacement a rule hides goes, and is nothing to bring back",
        start: () => {
          root.reset();
          root.sendId("hush", "Loud");
        },
        until: () => {
          if (root.ids.hush && root.find("Loud") && !("hush" in root.marks)) {
            root.mark("hush");
            root.send("-r", root.ids.hush, "Hushed");
          }
          if (!("hush" in root.marks) || root.find("Loud") || root.find("Hushed")) return false;
          root.plugin.restore();
          return !root.find("Hushed") && !root.find("Loud");
        }
      },
      {
        name: "a card closing before those shown keeps the pick in view",
        start: () => {
          root.reset();
          ["S1", "S2", "S3", "S4", "S5"].forEach(summary => root.send(summary));
        },
        until: () => {
          if (root.plugin.ordered.length < 5) return false;
          if (!("scrolled" in root.marks)) {
            root.mark("scrolled");
            root.plugin.summon();
            root.plugin.pick(root.plugin.showable[4]);
            root.plugin.dismiss(root.plugin.showable[0]);
          }
          return root.plugin.ordered.length === 4 && root.plugin.shown.includes(root.plugin.picked);
        }
      },
      {
        name: "a tag replacement of the card you reply to carries the reply over",
        start: () => {
          root.reset();
          root.chatSend("Tagged 1", "@a{sv} {'x-dunst-stack-tag': <'chat'>}");
        },
        until: () => {
          const first = root.find("Tagged 1");
          if (first && !("tagged" in root.marks)) {
            root.mark("tagged");
            root.plugin.reply(first);
            root.plugin.keepDraft(first, "Hi");
            root.chatSend("Tagged 2", "@a{sv} {'x-dunst-stack-tag': <'chat'>}");
          }
          const second = root.find("Tagged 2");
          return second !== null && !root.find("Tagged 1") && root.plugin.replying === second && second.draft === "Hi";
        }
      },
      {
        name: "dismissing the card you reply to ends the reply first, so it is kept to bring back",
        start: () => {
          root.plugin.endReply();
          root.reset();
          root.chatSend("Ray");
        },
        until: () => {
          const ray = root.find("Ray");
          if (ray && !("ray" in root.marks)) {
            root.mark("ray");
            root.plugin.reply(ray);
            root.plugin.dismiss(ray);
          }
          if (!("ray" in root.marks) || root.find("Ray")) return false;
          root.plugin.restore();
          return root.plugin.replying === null && root.find("Ray")?.restored === true;
        }
      },
      {
        name: "an empty reply sends nothing",
        start: () => {
          root.reset();
          root.chatSend("Una blank");
        },
        until: () => {
          const una = root.find("Una blank");
          if (!una) return false;
          root.plugin.reply(una);
          root.plugin.sendReply("  ", false);
          return root.plugin.replying === una && root.find("Una blank") !== null;
        }
      },
      {
        name: "held still, a card that came meanwhile keeps its place when its sender renews it",
        start: () => {
          root.plugin.endReply();
          root.reset();
          root.send("Base");
        },
        until: () => {
          if (root.find("Base") && !("renewHeld" in root.marks)) {
            root.mark("renewHeld");
            root.plugin.summon();
            root.sendId("held", "Held P1");
          }
          if (root.find("Held P1") && !("renewHeld2" in root.marks)) {
            root.mark("renewHeld2");
            root.send("Held Q");
          }
          if (root.find("Held Q") && !("renewHeld3" in root.marks)) {
            root.mark("renewHeld3");
            root.send("-r", root.ids.held, "Held P2");
          }
          if (!root.find("Held P2") || "renewHeld4" in root.marks) return "renewHeld4" in root.marks && root.plugin.ordered.map(each => each.summary).join() === "Base,Held P2,Held Q,Held Z";
          root.mark("renewHeld4");
          root.send("Held Z");
          return false;
        }
      },
      {
        name: "a tag replacement that takes no reply leaves the reply to end, its text copied",
        start: () => {
          root.plugin.release();
          root.reset();
          root.chatSend("Tag talk", "@a{sv} {'x-dunst-stack-tag': <'talk'>}");
        },
        until: () => {
          const talk = root.find("Tag talk");
          if (talk && !("talk" in root.marks)) {
            root.mark("talk");
            root.plugin.reply(talk);
            root.plugin.keepDraft(talk, "Keep me");
            root.send("-a", "Chat", "-h", "string:x-dunst-stack-tag:talk", "Tag plain");
          }
          return root.find("Tag plain") !== null && root.plugin.replying === null && Quickshell.clipboardText === "Keep me";
        }
      },
      {
        name: "bringing a card back while replying leaves the replied card in view",
        start: () => {
          root.plugin.release();
          root.reset();
          ["E1", "E2", "E3"].forEach(summary => root.send(summary));
        },
        until: () => {
          if (root.plugin.ordered.length === 3 && !("restoreReply" in root.marks)) {
            root.mark("restoreReply");
            root.chatSend("E reply");
          }
          const reply = root.find("E reply");
          if (!reply || "restoreReply2" in root.marks) return "restoreReply2" in root.marks && root.plugin.shown.includes(root.plugin.replying);
          root.mark("restoreReply2");
          root.plugin.reply(reply);
          root.plugin.restore();
          return false;
        }
      },
      {
        name: "as a list: the cards, then the closed struck; choosing a closed one brings it back",
        start: () => {
          root.plugin.release();
          root.reset();
          ["L1", "L2"].forEach(summary => root.send(summary));
        },
        until: () => {
          const p = root.plugin;
          if (!("listed" in root.marks)) {
            if (!root.find("L1") || !root.find("L2")) return false;
            root.mark("listed");
            p.dismiss(root.find("L1"));
            return false;
          }
          const items = p.items;
          if (!("chose" in root.marks)) {
            if (items.length < 2 || items[0].label !== "L2" || items[0].done || !items.some(item => item.label === "L1" && item.done)) return false;
            root.mark("chose");
            p.select(items.find(item => item.label === "L1").id);
            return false;
          }
          return root.find("L1") !== null && p.items.filter(item => item.label === "L1").length === 1 && !p.items.find(item => item.label === "L1").done;
        }
      },
      {
        name: "the same notification twice renews one card and counts it",
        start: () => {
          root.reset();
          root.send("-a", "twins", "Same", "said twice");
        },
        until: () => {
          const card = root.find("Same");
          if (!card) return false;
          if (!("twice" in root.marks)) {
            root.mark("twice");
            root.send("-a", "twins", "Same", "said twice");
            return false;
          }
          return card.repeats === 2 && root.plugin.ordered.filter(each => each.summary === "Same").length === 1;
        }
      },
      {
        name: "a silent rule sends it straight to those closed, and a rule's icon is the card's",
        start: () => {
          root.reset();
          root.send("-a", "hushed", "Hush");
          root.send("-a", "iconic", "Iconic");
        },
        until: () => {
          const iconic = root.find("Iconic");
          return iconic !== null && iconic.applied.icon === "dialog-information" && root.find("Hush") === null && root.plugin.items.some(item => item.label === "Hush" && item.done);
        }
      },
      {
        name: "a card brought back stays until dismissed, then goes back among those closed",
        start: () => {
          root.reset();
          root.plugin.settings.timeout = ({ low: 1, normal: 1 });
          root.send("Again");
        },
        until: () => {
          const again = root.find("Again");
          if (again && !again.restored && !("again" in root.marks)) {
            root.mark("again");
            root.plugin.dismiss(again);
            root.plugin.restore();
          }
          if (!("again" in root.marks) || root.mark("again") < 2000) return false;
          if (root.find("Again")?.restored && !("againGone" in root.marks)) {
            root.mark("againGone");
            root.plugin.dismiss(root.find("Again"));
          }
          const done = "againGone" in root.marks && !root.find("Again") && root.plugin.items.some(item => item.label === "Again" && item.done);
          if (done) root.plugin.settings.timeout = ({ low: 1, normal: 30 });
          return done;
        }
      },
      {
        name: "a closed one from another day says its day, as Clock does",
        start: () => {
          root.reset();
          root.send("Old news");
        },
        until: () => {
          const old = root.find("Old news");
          if (old && !("old" in root.marks)) {
            root.mark("old");
            old.arrived = Date.now() - 3 * 86400000;
            root.plugin.dismiss(old);
          }
          const item = root.plugin.items.find(item => item.label === "Old news" && item.done);
          return !!item && item.detail.endsWith(Clock.day(new Date(Date.now() - 3 * 86400000)));
        }
      },
      {
        name: "those closed are kept for a restart, history of them",
        start: () => {
          root.plugin.settings.history = 2;
          root.reset();
          ["Hist 1", "Hist 2", "Hist 3"].forEach(summary => root.send(summary));
        },
        until: () => {
          if (!("hist" in root.marks)) {
            if (!root.find("Hist 1") || !root.find("Hist 2") || !root.find("Hist 3")) return false;
            root.mark("hist");
            root.plugin.clear();
          }
          const kept = Array.from(Kept.value("notifications.closed") ?? []);
          const done = kept.length === 2 && kept.every(each => each.saved.summary.startsWith("Hist") && each.arrived > 0) && root.plugin.items.filter(item => item.done).length === 2;
          if (done) root.plugin.settings.history = 20;
          return done;
        }
      },
      {
        name: "the settings' check names what is wrong, and passes these",
        until: () => {
          const problems = root.plugin.settings.ruleProblems({ match: { nope: "x", body: "(", summary: "(?<app>x)" }, extra: 1, timeout: -1, urgency: "loud", ignorePause: "yes", actions: [{ key: "x", desc: "D", cmd: "c" }, { key: "q", cmd: "c", closes: "yes" }], run: 1 });
          const named = root.plugin.settings.ruleProblems({ match: { body: "(?<code>\\d+)" }, actions: [{ key: "a", desc: "Copy {code} {nope}", cmd: "c" }] });
          root.plugin.settings.timeout = ({ low: 1, normal: 30, critical: 5 });
          const extra = root.plugin.settings.problems();
          root.plugin.settings.timeout = ({ low: 1, normal: 30 });
          if (named.join() !== "actions[0] shows {nope}, which no group of its match names" || extra.join() !== "sets timeout.critical, none of low, normal") return false;
          if (!Validation.pluginProblems({ notifications: { corners: ["x"] } }).includes("plugins.notifications.corners is not a setting")) return false;
          if (JSON.stringify(Config.over({ low: 3, normal: 8 }, { normal: 5 })) !== '{"low":3,"normal":5}' || Config.over([1], [2])[0] !== 2) return false;
          return root.plugin.settings.problems().length === 0 && problems.length === 11 && root.plugin.settings.groupNames("(a)(?:b)(?<c>[(]d)\\(").join() === ",c" && problems.some(problem => problem.startsWith("matches body with '('")) && problems.includes("sets urgency to 'loud', none of low, normal, critical");
        }
      },
      {
        name: "an event or an answer titled as an option shows by the default reminder and Ask's notify, its title the summary",
        start: () => {
          const ask = Qt.createComponent(Quickshell.shellPath("plugins/ask/Settings.qml")).createObject(root);
          Commands.run(Config.calendar.remind, "--help", "14:00");
          Commands.run(ask.notify, "-x", "Done");
          ask.destroy();
        },
        until: () => root.find("--help")?.body === "14:00" && root.find("-x")?.body === "Done"
      }
    ]
  }
}
