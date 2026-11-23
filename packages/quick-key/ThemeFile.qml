import QtQuick
import Quickshell.Io

// A theme's colours, read again as the file changes, so one you edit or a tool rewrites (matugen, pywal) shows at once, and a colour it drops falls back.
FileView {
  id: root

  // Each colour by name, as #rgb, #rrggbb or #aarrggbb; set only here, as it loads.
  property var palette: ({})
  property bool missing: false

  watchChanges: true
  printErrors: false
  onFileChanged: reload()
  onLoadFailed: {
    missing = true;
    palette = {};
  }
  onLoaded: {
    missing = false;
    let read = {};
    try {
      read = JSON.parse(root.text());
    } catch (error) {
      console.warn("theme", root.path, "is no JSON:", error);
    }
    const colours = {};
    for (const [name, value] of Object.entries(read && typeof read === "object" ? read : {})) {
      if (typeof value === "string" && /^#([0-9a-fA-F]{3}|[0-9a-fA-F]{6}|[0-9a-fA-F]{8})$/.test(value)) colours[name] = value;
      else console.warn("theme", root.path + ":", name, "is no colour (#rrggbb, or #aarrggbb):", JSON.stringify(value));
    }
    palette = colours;
  }
}
