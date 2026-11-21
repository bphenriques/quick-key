import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.builtins
import qs.services
import qs.ui
import qs.widgets
import qs.widgets.menu
import qs.widgets.menu.calendar

// Every view the shell ships parses, those no other suite creates (Menu, Osd, plugins' views) among them; singletons compile wherever a suite uses them, and the imports register the modules they reach.
ShellRoot {
  id: root

  property var files: []
  // Why each file that does not compile does not.
  property var broken: []

  Process {
    running: true
    command: ["sh", "-c", "find \"$1\" -name '*.qml' ! -name shell.qml ! -name Suite.qml -exec grep -L '^pragma Singleton' {} +", "sh", Quickshell.shellDir]
    stdout: StdioCollector {
      onStreamFinished: root.files = text.trim().split("\n")
    }
  }

  Suite {
    cases: [
      {
        name: "the shell's views are found",
        until: () => root.files.length > 50
      },
      {
        name: "every view the shell ships parses",
        start: () => {
          // A window type needs a Wayland session, unavailable here; it is resolved after the file parsed.
          const unavailable = why => why.split("\n").every(line => /unavailable$|No PanelWindow backend loaded\.$/.test(line));
          root.broken = root.files.map(file => Qt.createComponent("file://" + file)).filter(component => component.status !== Component.Ready)
            .map(component => component.errorString().trim()).filter(why => !unavailable(why));
          for (const why of root.broken) console.warn("does not compile:", why);
        },
        until: () => root.broken.length === 0
      }
    ]
  }
}
