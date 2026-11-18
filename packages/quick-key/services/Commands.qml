pragma Singleton

import Quickshell

// A command from the config, run with sh -c, its arguments as $1, $2... so none is parsed by the shell.
Singleton {
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
}
