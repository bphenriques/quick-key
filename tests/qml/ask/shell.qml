import QtQuick
import Quickshell
import qs.services
import qs.ui

// The ask plugin over ACP with a stand-in agent (agent.py), each case a plugin and an agent of its own; qs.ui is imported for them.
ShellRoot {
  id: root

  property bool submitted: false
  property bool retried: false
  property bool refused: false
  // Whether a bare y, waiting on an approval, left it alone.
  property string bareY: ""
  property bool renewed: false
  property bool wasReset: false
  property int visitStep: 0
  property bool failedSent: false
  property int chooseStep: 0
  property var backs: []
  property int streamStep: 0
  property real byeAt: 0
  property int resumeStep: 0
  property bool listedOnce: false
  property bool recalledOnce: false

  // Sends a prompt once the plugin has loaded, then whether `done` holds for it.
  function asked(name, done) {
    const ask = Plugins.get(name);
    if (!ask) return false;
    if (!ask.exchanges.length) ask.send("hello");
    return done(ask);
  }

  Suite {
    cases: [
      {
        name: "an answer renders as rich text of the kit's own: its HTML escaped, a link and an image by their text, a table's header bold",
        until: () => {
          const html = Markup.html("<img src=x onerror=y> [site](https://example.com) ![pic](https://example.com/a.png)\n\n| A | B |\n|---|---|\n| 1 | 2 |");
          return html.includes("&lt;img src=x onerror=y&gt;") && html.includes("site") && html.includes("pic") && !/<a |<img|href|src=["h]/.test(html) && html.includes("<b>A</b>");
        }
      },
      {
        name: "the session it opens is kept, and an approval is answered by the user, never by a bare y, and stays as a step",
        until: () => root.asked("approved", ask => {
          if (ask.approval === "rm") {
            ask.typing = false;
            root.bareY = ask.act("y") || ask.approval !== "rm" ? "allowed" : "kept";
            ask.answerApproval(true);
          }
          return root.bareY === "kept" && ask.session === "s1" && ask.exchanges[0].reply === "allow" && ask.describe(ask.exchanges[0]).steps[0] === "Allowed: rm";
        })
      },
      {
        name: "typing, Escape leaves clearing and leaving to the prompt; waiting, it hides, a letter acts and its key gives the prompt the keys again",
        until: () => {
          const ask = Plugins.get("idle");
          if (!ask) return false;
          ask.toggle();
          const promptsOwn = ask.typing && !ask.act("Escape") && ask.escapeAction === "back" && ask.shown;
          ask.typing = false;
          ask.exchanges = [{ prompt: "p", image: "", reply: "r", error: "", stopped: false }];
          const letter = ask.act("l") && ask.exchanges.length === 0;
          const typing = ask.act("Tab") && ask.typing && !ask.act("l");
          const backtab = ask.act("Backtab") && !ask.typing && !ask.act("Backtab") && ask.act("Tab") && ask.typing;
          ask.typing = false;
          const hidden = ask.act("Escape") && !ask.shown;
          return promptsOwn && letter && typing && backtab && hidden;
        }
      },
      {
        name: "an input's text starts a new conversation answered in the background, and its after runs once answered",
        until: () => {
          const ask = Plugins.get("answered");
          if (!ask) return false;
          if (!root.submitted) {
            ask.session = "old";
            ask.exchanges = [{ prompt: "old", image: "", reply: "r", error: "", stopped: false }];
            ask.submit("new", true, "echo done > \"$XDG_RUNTIME_DIR/followed\"");
            root.submitted = true;
          }
          return ask.exchanges.length === 1 && ask.exchanges[0].reply === "new" && ask.session === "s2" && !ask.shown && ask.unread && Plugins.get("followed")?.text === "done";
        }
      },
      {
        name: "stopping cancels the turn, which the agent hears",
        until: () => root.asked("stopped", ask => {
          if (ask.busy && ask.activity === "thinking") {
            root.refused = ask.submit("more", true, "") === false;
            ask.stop();
          }
          return root.refused && ask.exchanges[0].stopped && !ask.busy && Plugins.get("trapped")?.text === "stopped";
        })
      },
      {
        name: "an input's new conversation drops a failed turn's prompt put back for a retry, and keeps text typed since",
        until: () => {
          const cleared = Plugins.get("cleared");
          const kept = Plugins.get("kept");
          if (!cleared || !kept) return false;
          for (const [ask, draft] of [[cleared, "failed"], [kept, "typed"]]) {
            ask.exchanges = [{ prompt: "failed", image: "", reply: "", error: "No answer", stopped: false }];
            ask.draft = draft;
            ask.submit("new", true, "");
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
        name: "while the menu shows its input, its turn shows there, the next working under the answer it follows, unread stays off, and the next send continues the conversation; a new visit starts fresh",
        until: () => {
          const ask = Plugins.get("visitor");
          if (!ask) return false;
          if (root.visitStep === 0) {
            Plugins.watching = "visitor\n{}";
            root.visitStep = ask.submit("one", false, "") ? 1 : 0;
          } else if (root.visitStep === 1 && ask.turn?.text === "one") {
            root.visitStep = ask.submit("two", false, "") && ask.busy && ask.turn?.phase === "working" && ask.turn.question === "two" && ask.turn.context === "one" ? 2 : -1;
          } else if (root.visitStep === 2 && ask.turn?.text === "two" && ask.turn.phase === "answered") {
            root.visitStep = ask.exchanges.length === 2 && !ask.unread ? 3 : -1;
            Plugins.watching = "";
            root.visitStep = ask.turn === null && ask.submit("three", true, "") ? root.visitStep + 1 : -1;
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
            Plugins.watching = "unanswered\n{}";
            root.failedSent = ask.submit("lost", false, "");
          }
          const done = ask.turn?.phase === "failed" && ask.draft === "";
          if (done) Plugins.watching = "";
          return done;
        }
      },
      {
        name: "an answer's options are the choices: Escape sets them aside, a send brings them back, a digit picks one as the next message; a table stays marked",
        until: () => {
          const ask = Plugins.get("chooser");
          if (!ask || ask.busy) return false;
          switch (root.chooseStep) {
          case 0:
            Plugins.watching = "chooser\n{}";
            root.chooseStep = ask.submit("pick one", false, "") ? 1 : -1;
            return false;
          case 1:
            root.chooseStep = ask.turn?.phase === "choosing" && ask.turn.options.length === 2 && ask.choices.length === 2 && ask.escapeAction === "type" && ask.act("Escape") && ask.aside
              && ask.choices.length === 0 && !ask.act("1") && ask.submit("pick again", false, "") ? 2 : -1;
            return false;
          case 2:
            root.chooseStep = !ask.aside && ask.choices.length === 2 && ask.act("2") ? 3 : -1;
            return false;
          case 3:
            root.chooseStep = ask.exchanges[ask.exchanges.length - 1].prompt === "b" && ask.exchanges[ask.exchanges.length - 1].reply === "b" && ask.submit("a table", false, "") ? 4 : -1;
            return false;
          }
          const done = root.chooseStep === 4 && ask.turn?.table === true && ask.turn.phase === "answered" && ask.turn.options.length === 0;
          if (done) Plugins.watching = "";
          return done;
        }
      },
      {
        name: "expanded from a menu, stepping back says so; leaving any other way says not",
        until: () => {
          const ask = Plugins.get("expander");
          if (!ask) return false;
          ask.expand(returning => root.backs = root.backs.concat([returning]));
          const shown = ask.shown;
          ask.typing = false;
          const stepped = ask.escapeAction === "menu" && ask.act("Escape") && !ask.shown;
          ask.expand(returning => root.backs = root.backs.concat([returning]));
          ask.shown = false;
          return shown && stepped && root.backs.join() === "true,false" && ask.backTo === null;
        }
      },
      {
        name: "asking again what failed keeps its after",
        until: () => {
          const ask = Plugins.get("retried");
          if (!ask) return false;
          if (!root.retried) {
            ask.exchanges = [{ prompt: "again", image: "", reply: "", error: "No answer", stopped: false, after: "echo done > \"$XDG_RUNTIME_DIR/refollowed\"" }];
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
        name: "recall lists the agent's conversations in the picker, as it orders them, each to resume and the last activity on its right",
        until: () => {
          const ask = Plugins.get("recaller");
          if (!ask) return false;
          if (!root.recalledOnce) root.recalledOnce = ask.recall(null);
          const [old, older] = ask.items;
          return Picker.list === "recaller" && !ask.listing && ask.items.length === 2 && old.label === "An old question" && old.verb === "resume" && old.enabled
            && old.detail === Clock.recent(new Date("2026-11-01T10:00:00Z")) && older.label === "older" && ask.recalls;
        }
      },
      {
        name: "resuming one replays its history as the conversation, lit in the list, and the next turn carries it on",
        until: () => {
          const ask = Plugins.get("recaller");
          if (root.resumeStep === 0) {
            ask.select("old");
            root.resumeStep = ask.resuming && ask.shown ? 1 : -1;
          } else if (root.resumeStep === 1 && !ask.busy) {
            root.resumeStep = ask.exchanges.length === 1 && ask.exchanges[0].prompt === "what was it?" && ask.exchanges[0].reply === "from before" && ask.items[0].active && ask.send("next", "") ? 2 : -1;
          }
          return root.resumeStep === 2 && !ask.busy && ask.session === "old" && ask.exchanges.length === 2 && ask.exchanges[1].reply === "next";
        }
      },
      {
        name: "an agent that ends before listing says why, and the list is empty",
        until: () => {
          const ask = Plugins.get("unlisted");
          if (!ask) return false;
          if (!root.listedOnce) root.listedOnce = ask.recall(null);
          return !ask.listing && ask.items.length === 0 && ask.error !== "";
        }
      },
      {
        name: "its status shows its glyph only while it has something to report",
        until: () => Plugins.get("idle")?.glyph === "" && Plugins.get("idle").settings.glyph !== ""
      },
      {
        name: "a moment is said one way everywhere: near days by name, the week by weekday, else the date, with its year when not this one; short names cut to three letters only where that still tells them apart",
        until: () => {
          const day = 86400000;
          const at = days => new Date(Date.now() + days * day);
          const now = Clock.date;
          const lastYear = new Date(now.getFullYear() - 1, 5, 3, 9, 30);
          return /^\d\d:\d\d$/.test(Clock.recent(new Date())) && Clock.recent(at(-1)) === "yesterday" && Clock.day(at(1)) === "tomorrow"
            && Clock.recent(at(-3)) === Clock.weekdays[at(-3).getDay()] && Clock.day(at(-10)) === Clock.format(at(-10), "%-d %b")
            && Clock.day(lastYear) === "3 " + Clock.months[5] + " " + lastYear.getFullYear()
            && Clock.when(new Date(now.getFullYear(), now.getMonth(), now.getDate() + 1, 9, 30), true) === "tomorrow " + Clock.time(new Date(2000, 0, 1, 9, 30))
            && Clock.heading(now) === "Today"
            && JSON.stringify(Clock.abbreviated(["Sept", "Oct"])) === '["Sep","Oct"]' && JSON.stringify(Clock.abbreviated(["janv.", "juin", "juil."])) === '["janv","juin","juil"]';
        }
      }
    ]
  }
}
