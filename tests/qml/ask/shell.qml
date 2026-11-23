import QtQuick
import Quickshell
import qs.services
import qs.ui
import qs.ui.conversation

// The ask plugin over ACP with a stand-in agent (agent.py), each case a plugin and an agent of its own; qs.ui is imported for them.
ShellRoot {
  id: root

  property bool submitted: false
  property bool retried: false
  property bool refused: false
  // Whether stepping back left the panel with the run still going.
  property string leftRunning: ""
  // Whether, waiting on an approval, it said it was blocked on permission.
  property bool blocked: false
  property bool renewed: false
  property bool wasReset: false
  // The list Picker was last asked for.
  property string picked: ""

  Connections {
    target: Picker

    function onRequested(list) {
      root.picked = list;
    }
  }
  property int visitStep: 0
  property bool failedSent: false
  property int streamStep: 0
  property real byeAt: 0
  property int resumeStep: 0
  property bool listedOnce: false
  property bool recalledOnce: false
  property var lateStep: ({})
  property real resumerAt: 0
  property bool resumed: false

  // Sends a prompt once the plugin has loaded, then whether `done` holds for it.
  function asked(name, done) {
    const ask = Plugins.get(name);
    if (!ask) return false;
    if (!ask.exchanges.length) ask.send("hello");
    return done(ask);
  }

  // Stops a slow turn and sends the next at once, then whether `done` holds for it.
  function stoppedThenSent(name, done) {
    const ask = Plugins.get(name);
    if (!ask) return false;
    if (!lateStep[name]) lateStep[name] = ask.send("slow", "") ? 1 : -1;
    else if (lateStep[name] === 1 && ask.activity === "thinking") {
      ask.stop();
      lateStep[name] = ask.send("next", "") ? 2 : -1;
    }
    return lateStep[name] === 2 && !ask.busy && ask.exchanges[0].stopped && ask.exchanges[1]?.reply === "next" && done(ask);
  }

  Suite {
    cases: [
      {
        name: "without a terminal to open, C-o keeps the conversation and is not offered",
        until: () => {
          const ask = Plugins.get("sealed");
          if (!ask) return false;
          if (!ask.exchanges.length) {
            ask.exchanges = [{ prompt: "p", reply: "r", error: "", stopped: false }];
            ask.act("Ctrl+o");
          }
          return ask.exchanges.length === 1 && !ask.canMove;
        }
      },
      {
        name: "a compact line is the answer's blocks as plain text: a heading indented too, code as written, a table's rows as columns, a rule dropped",
        until: () => Markup.plain("  ## Setup\n##not one") === "Setup\n##not one"
          && Markup.plain("Use **this**:\n\n```sh\nmake `x`\n```\n\n| A | B |\n|---|---|\n| [one](u) | 2 |\n\n---\n\n> quoted *word*") === "Use this:\nmake `x`\nA  B\none  2\nquoted word"
      },
      {
        name: "a key runs only while it shows, C-C copying the last answer; Escape stays the prompt's and Tab types nothing",
        until: () => {
          const ask = Plugins.get("keyed");
          if (!ask) return false;
          ask.exchanges = [{ prompt: "p", reply: "r", error: "", stopped: false }];
          const prompts = !ask.act("Escape") && ask.act("Tab");
          return prompts && !ask.act("Ctrl+y") && ask.act("Ctrl+C") && Quickshell.clipboardText === "r" && ask.act("Ctrl+l") && ask.exchanges.length === 0;
        }
      },
      {
        name: "C-? lists the keys the bar leaves out, as ? does elsewhere; any key but a modifier alone closes it, typing nothing",
        until: () => {
          const ask = Plugins.get("keyed");
          const listed = ask.act("Ctrl+?") && ask.helping && ask.help.some(key => key.key === "Shift+Return") && ask.keys.some(key => key.key === "Ctrl+?" && key.shows());
          const kept = !ask.act("") && ask.helping;
          return listed && kept && ask.act("x") && !ask.helping && !ask.act("x");
        }
      },
      {
        name: "an answer renders as rich text of the kit's own: its HTML escaped, a link and an image by their text, a table's header bold",
        until: () => {
          const html = Markup.html("<img src=x onerror=y> [site](https://example.com) ![pic](https://example.com/a.png)\n\n| A | B |\n|---|---|\n| 1 | 2 |");
          return html.includes("&lt;img src=x onerror=y&gt;") && html.includes("site") && html.includes("pic") && !/<a |<img|href|src=["h]/.test(html) && html.includes("<b>A</b>");
        }
      },
      {
        name: "an answer is drawn in pieces of whole blocks as written, a fence, a loose list and a table each whole, and a fence still streaming in runs to the end",
        until: () => {
          const blocks = Markup.split("# Plan\npara line\nmore\n\n```\na\n\nb\n```\n- x\n\n- y\n\n| a | b |\n|---|---|\n| 1 | 2 |\n\n```\nopen\n\nstill", 0);
          const pieces = Markup.split("aaa\n\nb\n\ncc\n\nd", 3);
          return JSON.stringify(blocks) === JSON.stringify(["# Plan", "para line\nmore", "```\na\n\nb\n```", "- x\n\n- y", "| a | b |\n|---|---|\n| 1 | 2 |", "```\nopen\n\nstill"]) && JSON.stringify(pieces) === JSON.stringify(["aaa", "b\n\ncc", "d"]);
        }
      },
      {
        name: "the session it opens is kept, and an approval, which blocks it on permission, is answered by the user with C-y, and stays as a step",
        until: () => root.asked("approved", ask => {
          if (ask.approval === "rm") {
            root.blocked = ask.phase === "blocked" && ask.kind === "permission" && ask.busy && ask.describe(ask.exchanges[0]).kind === "permission";
            ask.act("Ctrl+y");
          }
          return root.blocked && ask.session === "s1" && ask.exchanges[0].reply === "allow" && ask.describe(ask.exchanges[0]).steps[0] === "Allowed: rm";
        })
      },
      {
        name: "stopping while it waits on an approval answers the request cancelled",
        until: () => root.asked("asked", ask => {
          if (ask.approval === "rm") ask.stop();
          return !ask.busy && ask.exchanges[0].stopped && Plugins.get("s6log")?.text === "permission cancelled";
        })
      },
      {
        name: "approvals asked at once are each answered in turn, and one offered only for good is cancelled, saying so",
        until: () => root.asked("twice", ask => {
          if (ask.approval) ask.answerApproval(true);
          return !ask.busy && ask.exchanges[0].reply === "allow cancelled" && JSON.stringify(ask.exchanges[0].steps) === JSON.stringify(["Allowed: one", ask.words.notOnce("two")]);
        })
      },
      {
        name: "a turn sent right after a stop waits for the stopped one, so none of its last words land in it",
        until: () => root.stoppedThenSent("late", ask => Plugins.get("s8log")?.text === "initialize")
      },
      {
        name: "an agent deaf to the stop is stopped, and the turn waiting on it starts it again",
        timeout: 8000,
        until: () => root.stoppedThenSent("deaf", ask => Plugins.get("s9log")?.text === "load s9")
      },
      {
        name: "once gone, an agent that resumes but cannot load resumes the session, not a new one",
        until: () => root.asked("resumer", ask => {
          if (!root.resumerAt && !ask.busy && ask.exchanges[0].reply === "hello" && ask.send("bye", "")) root.resumerAt = Date.now();
          if (!root.resumed && root.resumerAt && !ask.busy && Date.now() - root.resumerAt > 1500) root.resumed = ask.send("again", "");
          return root.resumed && !ask.busy && ask.exchanges[2].reply === "again" && Plugins.get("s10log")?.text === "resume s10" && ask.session === "s10";
        })
      },
      {
        name: "an input's text starts a new conversation answered in the background, and its after runs once answered",
        until: () => {
          const ask = Plugins.get("answered");
          if (!ask) return false;
          if (!root.submitted) {
            ask.session = "old";
            ask.exchanges = [{ prompt: "old", reply: "r", error: "", stopped: false }];
            ask.submit("new", "echo done > \"$XDG_RUNTIME_DIR/followed\"");
            root.submitted = true;
          }
          return ask.exchanges.length === 1 && ask.exchanges[0].reply === "new" && ask.session === "s2" && !ask.shown && ask.unread && Plugins.get("followed")?.text === "done";
        }
      },
      {
        name: "stepping back leaves a run going and C-c stops it, which the agent hears; C-r lists nothing meanwhile",
        until: () => root.asked("stopped", ask => {
          if (ask.busy && ask.activity === "thinking" && !root.leftRunning) {
            root.refused = ask.submit("more", "") === false && !ask.act("Ctrl+r") && !ask.recall();
            ask.show();
            Panels.back();
            root.leftRunning = !ask.shown && ask.busy ? "yes" : "no";
            ask.act("Ctrl+c");
          }
          return root.refused && root.leftRunning === "yes" && ask.exchanges[0].stopped && !ask.busy && Plugins.get("trapped")?.text === "stopped";
        })
      },
      {
        name: "an input's new conversation drops a failed turn's prompt put back for a retry, and keeps text typed since",
        until: () => {
          const cleared = Plugins.get("cleared");
          const kept = Plugins.get("kept");
          if (!cleared || !kept) return false;
          for (const [ask, draft] of [[cleared, "failed"], [kept, "typed"]]) {
            ask.exchanges = [{ prompt: "failed", reply: "", error: "No answer", stopped: false }];
            ask.draft = draft;
            ask.submit("new", "");
          }
          return cleared.draft === "" && kept.draft === "typed";
        }
      },
      {
        name: "a new conversation mid-turn stops it and drops its prompt rather than putting it back",
        until: () => {
          const ask = Plugins.get("renewed");
          if (!ask) return false;
          if (!root.renewed) root.renewed = ask.send("going");
          if (ask.busy && ask.activity === "thinking") {
            ask.reset();
            root.wasReset = true;
          }
          return root.wasReset && !ask.busy && ask.exchanges.length === 0 && ask.draft === "";
        }
      },
      {
        name: "while the menu shows its input, its turn shows there, unread stays off, and the next send continues the conversation; a new visit starts fresh",
        until: () => {
          const ask = Plugins.get("visitor");
          if (!ask) return false;
          if (root.visitStep === 0) {
            ask.startVisit();
            root.visitStep = ask.submit("one", "") ? 1 : 0;
          } else if (root.visitStep === 1 && ask.turn?.text === "one") {
            root.visitStep = ask.submit("two", "") && ask.busy && ask.turn?.phase === "working" && ask.turn.question === "two" ? 2 : -1;
          } else if (root.visitStep === 2 && ask.turn?.text === "two" && ask.turn.phase === "done") {
            root.visitStep = ask.exchanges.length === 2 && !ask.unread ? 3 : -1;
            ask.endVisit();
            root.visitStep = ask.turn === null && ask.submit("three", "") ? root.visitStep + 1 : -1;
          }
          return root.visitStep === 4 && !ask.busy && ask.exchanges.length === 1 && ask.unread;
        }
      },
      {
        name: "a failed answer shows in alert where the menu shows it, and stays out of the panel's prompt",
        until: () => {
          const ask = Plugins.get("unanswered");
          if (!ask) return false;
          if (!root.failedSent) {
            ask.startVisit();
            root.failedSent = ask.submit("lost", "");
          }
          const done = ask.turn?.phase === "error" && ask.draft === "";
          if (done) ask.endVisit();
          return done;
        }
      },
      {
        name: "an answer that is a table stays marked, so the menu opens the panel on it",
        start: () => {
          Plugins.get("chooser").startVisit();
          Plugins.get("chooser").submit("a table", "");
        },
        until: () => {
          const ask = Plugins.get("chooser");
          const done = ask.turn?.table === true && ask.turn.phase === "done";
          if (done) ask.endVisit();
          return done;
        }
      },
      {
        name: "expanded over what opened it, stepping back shows that again, and closing hides both",
        until: () => {
          const ask = Plugins.get("expander");
          if (!ask) return false;
          // The suite stands in for the menu the panel opens over.
          Panels.open(root);
          ask.expand();
          const shown = ask.shown;
          Panels.back();
          const stepped = !ask.shown && Panels.top === root;
          ask.expand();
          Panels.close();
          return shown && stepped && !ask.shown && Panels.top === null;
        }
      },
      {
        name: "asking again what failed keeps its after",
        until: () => {
          const ask = Plugins.get("retried");
          if (!ask) return false;
          if (!root.retried) {
            ask.exchanges = [{ prompt: "again", reply: "", error: "No answer", stopped: false, after: "echo done > \"$XDG_RUNTIME_DIR/refollowed\"" }];
            root.retried = ask.send("again", "");
          }
          return ask.exchanges.length === 1 && ask.exchanges[0].reply === "again" && Plugins.get("refollowed")?.text === "done";
        }
      },
      {
        name: "an answer streams in; the agent stays between turns, and once it is gone the next turn loads the session; a tool toolMatch names runs toolRun",
        until: () => {
          const ask = Plugins.get("streamer");
          if (!ask) return false;
          const log = Plugins.get("s4log")?.text ?? "";
          switch (root.streamStep) {
          case 0:
            root.streamStep = ask.send("stream", "") ? 1 : -1;
            break;
          case 1:
            if (ask.busy && ask.exchanges[0].reply === "one ") root.streamStep = 2;
            break;
          case 2:
            if (!ask.busy) root.streamStep = ask.exchanges[0].reply === "one two three" && ask.send("again", "") ? 3 : -1;
            break;
          case 3:
            if (!ask.busy && log === "initialize" && ask.send("bye", "")) root.streamStep = 4;
            break;
          case 4:
            if (!ask.busy && !root.byeAt) root.byeAt = Date.now();
            if (root.byeAt && Date.now() - root.byeAt > 1000) root.streamStep = ask.send("tool", "") ? 5 : -1;
            break;
          }
          return root.streamStep === 5 && !ask.busy && ask.exchanges[ask.exchanges.length - 1].reply === "added" && log === "load s4" && Plugins.get("synced")?.text === "synced";
        }
      },
      {
        name: "recall lists the agent's conversations in the picker, every page, as it orders them, each to resume and the last activity on its right",
        until: () => {
          const ask = Plugins.get("recaller");
          if (!ask) return false;
          if (!root.recalledOnce) root.recalledOnce = ask.recall();
          const [old, older] = ask.items;
          return root.picked === "recaller" && !ask.listing && ask.items.length === 2 && old.label === "An old question" && old.verb === "resume" && old.enabled
            && old.detail === Clock.recent(new Date("2026-11-01T10:00:00Z")) && older.label === "older" && ask.recalls;
        }
      },
      {
        name: "resuming one replays its history as the conversation, lit in the list, and the next turn carries it on",
        until: () => {
          const ask = Plugins.get("recaller");
          if (root.resumeStep === 0) {
            ask.select("old");
            root.resumeStep = ask.stage === "resuming" && ask.shown ? 1 : -1;
          } else if (root.resumeStep === 1 && !ask.busy) {
            root.resumeStep = ask.exchanges.length === 1 && ask.exchanges[0].prompt === "what was it?" && ask.exchanges[0].reply === "from before" && ask.items[0].active && ask.send("next", "") ? 2 : -1;
          }
          return root.resumeStep === 2 && !ask.busy && ask.session === "old" && ask.exchanges.length === 2 && ask.exchanges[1].reply === "next";
        }
      },
      {
        name: "a conversation cleared, then resumed, is loaded again, its history replayed",
        start: () => {
          Plugins.get("recaller").reset();
          Plugins.get("recaller").select("old");
        },
        until: () => Plugins.get("recaller").stage === "idle" && Plugins.get("recaller").exchanges[0]?.reply === "from before"
      },
      {
        name: "a conversation that fails to load says why, rather than starting a new one in its place",
        start: () => Plugins.get("recaller").select("gone"),
        until: () => {
          const ask = Plugins.get("recaller");
          return ask.stage === "idle" && ask.exchanges.length === 0 && ask.error === "Resource not found" && ask.session === "";
        }
      },
      {
        name: "an agent that ends before listing says why, and the list is empty",
        until: () => {
          const ask = Plugins.get("unlisted");
          if (!ask) return false;
          if (!root.listedOnce) root.listedOnce = ask.recall();
          return !ask.listing && ask.items.length === 0 && ask.error !== "";
        }
      },
      {
        name: "its status shows its glyph only while it has something to report",
        until: () => Plugins.get("idle")?.glyph === "" && Plugins.get("idle").settings.glyph !== ""
      },
      {
        name: "a moment is said one way everywhere: near days by name, the coming week by weekday, else the date (the past too), with its year when not this one; short names cut to three letters only where that still tells them apart",
        until: () => {
          const day = 86400000;
          const at = days => new Date(Date.now() + days * day);
          const now = Clock.date;
          const lastYear = new Date(now.getFullYear() - 1, 5, 3, 9, 30);
          return /^\d\d:\d\d$/.test(Clock.recent(new Date())) && Clock.recent(at(-1)) === "yesterday" && Clock.day(at(1)) === "tomorrow"
            && Clock.day(at(3)) === Clock.weekdays[at(3).getDay()] && Clock.recent(at(-3)) === Clock.format(at(-3), "%-d %b") && Clock.day(at(-10)) === Clock.format(at(-10), "%-d %b")
            && Clock.day(lastYear) === "3 " + Clock.months[5] + " " + lastYear.getFullYear()
            && Clock.when(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 9, 30), true) === "tomorrow " + Clock.time(new Date(2000, 0, 1, 9, 30))
            && Clock.heading(now) === "Today"
            && JSON.stringify(Clock.abbreviated(["Sept", "Oct"])) === '["Sep","Oct"]' && JSON.stringify(Clock.abbreviated(["janv.", "juin", "juil."])) === '["janv","juin","juil"]';
        }
      }
    ]
  }
}
