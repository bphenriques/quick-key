pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A command from the config, run with sh -c, its arguments as $1, $2... so none is parsed by the shell.
Singleton {
  id: root

  function line(shell, ...args) {
    return ["sh", "-c", shell + args.map((_, i) => ' "$' + (i + 1) + '"').join(""), "sh", ...args];
  }

  // Runs it and forgets it; nothing when unset.
  function run(shell, ...args) {
    if (shell) Quickshell.execDetached(line(shell, ...args));
  }

  // Runs it as run does, then `after`, given no arguments, once it exits 0.
  function runThen(shell, after, ...args) {
    if (!after) return run(shell, ...args);
    const [sh, c, script, ...rest] = line(shell, ...args);
    if (shell) Quickshell.execDetached([sh, c, "{ " + script + "\n} && { set --\n" + after + "\n}", ...rest]);
  }

  // Runs it with these variables beside the environment (a notification's NOTIFICATION_*), so what they hold is never read as a command.
  function runWith(shell, environment) {
    if (shell) withEnvironment.createObject(root, { command: ["sh", "-c", shell], environment: environment }).running = true;
  }

  // `running` is set once made, never declared: one that turns true before `command` is set starts nothing.
  Component {
    id: withEnvironment

    Process {
      onExited: destroy()
    }
  }
}
