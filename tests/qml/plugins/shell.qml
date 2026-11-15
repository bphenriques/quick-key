import QtQuick
import Quickshell
import qs.services
import qs.ui

// How plugins load, read their source and turn its state into what they show; qs.ui is imported for the shipped ones.
ShellRoot {
  id: root

  // Every text the watcher has shown, in order.
  property var watched: []
  // The ticker's value a second into the case that waits with the menu closed.
  property string ticked: ""

  Suite {
    id: suite

    cases: [
      {
        name: "a read command's last line is its state, plain text its text",
        until: () => Plugins.get("lastLine")?.text === "second"
      },
      {
        name: "a watch's state clears when it exits",
        until: () => root.watched.slice(0, 2).join() === "up,"
      },
      {
        name: "a file is read once it appears",
        start: () => Quickshell.execDetached(["sh", "-c", 'echo /walls/sunset.jpg > "$XDG_RUNTIME_DIR/wallpaper"']),
        until: () => Plugins.get("wallpaper")?.text === "sunset"
      },
      {
        name: "a plugin in the user's folder loads",
        until: () => Plugins.get("custom")?.text === "from the user's folder"
      },
      {
        name: "a plugin in a folder of its own loads, its views created with it",
        until: () => Plugins.get("folded")?.text === "from its folder"
      },
      {
        name: "a plugin's settings are its Settings.qml, set from config.json over its defaults",
        until: () => Plugins.get("folded")?.settings.greeting === "hi" && Plugins.get("folded").settings.count === 3 && !("unknown" in Plugins.get("folded").settings)
      },
      {
        name: "a plugin that fails to load is left out",
        until: () => Plugins.get("broken") === null && Plugins.get("lastLine") !== null
      },
      {
        name: "show gives a value its look",
        until: () => Plugins.get("paused")?.glyph === "B" && Plugins.get("paused").tone === "alert" && Plugins.get("paused").active
      },
      {
        name: "a line's own fields win over the look show gives its value",
        until: () => Plugins.get("override")?.text === "live" && Plugins.get("override").detail === "d"
      },
      {
        name: "static items light by value, dim unless enabled, and give the status its label and icon",
        until: () => JSON.stringify((Plugins.get("layouts")?.items ?? []).map(item => [item.id, item.active, item.enabled])) === '[["a",false,true],["b",true,true],["c",false,false]]'
          && Plugins.get("layouts").text === "B" && Plugins.get("layouts").glyph === "I"
      },
      {
        name: "a read with every waits while the menu is closed",
        until: () => {
          if (suite.waited === 1000) root.ticked = Plugins.get("ticker")?.text ?? "";
          return suite.waited >= 3000 && Plugins.get("ticker")?.text === root.ticked;
        }
      },
      {
        name: "a read with every reads again while the menu is open",
        start: () => Plugins.menuOpen = true,
        until: () => Number(Plugins.get("ticker")?.text) >= Number(root.ticked) + 2
      }
    ]
  }

  Connections {
    target: Plugins.get("watcher")
    function onTextChanged() {
      root.watched = root.watched.concat([target.text]);
    }
  }
}
