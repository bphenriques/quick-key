import QtQuick
import Quickshell
import qs.services
import qs.ui

// The ask plugin's protocol with its command (docs/src/plugins.md), each case a plugin and a command of its own; qs.ui is imported for them.
ShellRoot {
  id: root

  property bool submitted: false
  property bool retried: false
  property bool refused: false
  property bool renewed: false
  property bool wasReset: false
  property int visitStep: 0
  property bool failedSent: false
  property int chooseStep: 0
  property var backs: []

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
        name: "the session it names is kept, and an approval is answered on its stdin",
        until: () => root.asked("approved", ask => {
          if (ask.approval === "rm") ask.answerApproval(true);
          return ask.session === "s1" && ask.exchanges[0].reply === "allow";
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
        name: "stopping ends the command, which may trap its end",
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
            root.chooseStep = ask.turn?.phase === "choosing" && ask.turn.options.length === 2 && ask.choices.length === 2 && ask.escapeAction === "aside" && ask.act("Escape") && ask.aside
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
      }
    ]
  }
}
