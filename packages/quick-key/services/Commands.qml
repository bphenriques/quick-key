pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// A command from the config, run with sh -c, its arguments as $1, $2... so none is parsed by the shell.
Singleton {
  id: root

  // A trailing newline (a multi-line Nix string) would leave the arguments a command of their own, and no text would run the first: that fails, as `false`.
  function line(shell, ...args) {
    const script = (shell ?? "").replace(/\s+$/, "");
    return script ? ["sh", "-c", script + args.map((_, i) => ' "$' + (i + 1) + '"').join(""), "sh", ...args] : ["false"];
  }

  function run(shell, ...args) {
    if (shell) Quickshell.execDetached(line(shell, ...args));
  }

  // Runs it as run does, then `after`, given no arguments, once it exits 0.
  function runThen(shell, after, ...args) {
    if (!after) return run(shell, ...args);
    const [sh, c, script, ...rest] = line(shell, ...args);
    if (script) Quickshell.execDetached([sh, c, "{ " + script + "\n} && { set --\n" + after + "\n}", ...rest]);
  }

  // Runs it with these variables beside the environment (a notification's NOTIFICATION_*), so what they hold is never read as a command.
  function runWith(shell, environment) {
    if (shell) withEnvironment.createObject(root).exec({ command: ["sh", "-c", shell], environment: environment });
  }

  Component {
    id: withEnvironment

    Process {
      onExited: destroy()
    }
  }
}
