import QtQuick
import Quickshell
import qs.services
import qs.ui

// The ask plugin's protocol with its command (docs/src/plugins.md), each case a plugin and a command of its own; qs.ui is imported for them.
ShellRoot {
  id: root

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
        name: "Escape leaves the prompt, then hides; waiting, a letter acts and its key gives the prompt the keys again",
        until: () => {
          const ask = Plugins.get("idle");
          if (!ask) return false;
          ask.toggle();
          ask.act("Escape");
          const left = ask.shown && !ask.typing;
          ask.exchanges = [{ prompt: "p", image: "", reply: "r", error: "", stopped: false }];
          const letter = ask.act("l") && ask.exchanges.length === 0;
          const typing = ask.act("a") && ask.typing && !ask.act("l");
          ask.typing = false;
          ask.lastEscape = 0;
          ask.act("Escape");
          return left && letter && typing && !ask.shown;
        }
      },
      {
        name: "stopping ends the command, which may trap its end",
        until: () => root.asked("stopped", ask => {
          if (ask.activity === "thinking") ask.stop();
          return ask.exchanges[0].stopped && !ask.busy && Plugins.get("trapped")?.text === "stopped";
        })
      }
    ]
  }
}
