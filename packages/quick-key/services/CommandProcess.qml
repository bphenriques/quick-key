import QtQuick
import Quickshell.Io

// A command from the config whose failure is logged with its last word on stderr, which a Process left without a parser drops.
Process {
  id: root

  property string complaint: ""

  onStarted: complaint = ""
  onExited: code => {
    if (code !== 0) console.warn("command exited " + code + (complaint ? " (" + complaint + ")" : "") + ":", String(command[2] ?? command).slice(0, 80));
  }

  stderr: SplitParser {
    onRead: line => {
      if (line.trim()) root.complaint = line.trim();
    }
  }
}
