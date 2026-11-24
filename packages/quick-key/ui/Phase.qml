pragma Singleton

import QtQuick
import Quickshell

// Work as Rex's Program Status Protocol names it, one vocabulary for every surface: idle, working, blocked on you, done (a result not seen yet) or error.
Singleton {
  readonly property var names: ["idle", "working", "blocked", "done", "error"]

  // A phase a source gave; an unknown word is idle, so a later one never reads as another.
  function of(value) {
    return names.includes(value) ? value : "idle";
  }

  // Its tone where it reports: blocked warns, error alerts, done is lit until seen; idle and working keep theirs, working with a spinner.
  function tone(phase) {
    return phase === "blocked" ? "warning" : phase === "error" ? "alert" : phase === "done" ? "primary" : "";
  }
}
