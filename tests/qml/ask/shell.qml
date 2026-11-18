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
          const typing = ask.act("a") && ask.typing && !ask.act("l");
          ask.typing = false;
          const hidden = ask.act("Escape") && !ask.shown;
          return promptsOwn && letter && typing && hidden;
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
