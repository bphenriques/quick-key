import QtQuick
import Quickshell

// Checks config.json and exits, with 1 when anything is wrong with it; shows nothing (docs/src/configuration.md).
ShellRoot {
  id: root

  readonly property var problems: Validation.problems

  function finish() {
    if (problems !== null) Qt.exit(problems.length ? 1 : 0);
  }

  onProblemsChanged: finish()
  Component.onCompleted: finish()
}
