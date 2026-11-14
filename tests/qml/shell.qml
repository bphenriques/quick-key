import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui
import qs.widgets.menu

// Each case waits up to five seconds for its condition, then prints `ok` or `not ok`; the plugins are config/'s.
ShellRoot {
  id: root

  property int index: -1
  property int waited: 0
  // Every text the watcher has shown, in order.
  property var watched: []

  readonly property var cases: [
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
      name: "a plugin that fails to load is left out",
      until: () => Plugins.get("broken") === null && Plugins.get("lastLine") !== null
    },
    {
      name: "pinned items keep their digits, dimmed while absent; the rest follow",
      until: () => JSON.stringify(menu.numbered("devices", [{ match: "b-*", label: "Bee" }, { match: "z-*", label: "Zed" }])
        .map(item => [item.key, item.desc, item.enabled !== false])) === '[["1","Bee",true],["2","Zed",false],["3","a-1",true]]'
    },
    {
      name: "keys show Emacs-style",
      until: () => MenuKeys.label(["Ctrl+Left", "Ctrl+Right"], true) === "C-←→" && MenuKeys.label("Return") === "RET" && MenuKeys.label("Alt+k") === "M-k"
    }
  ]

  function next() {
    index++;
    if (index === cases.length) {
      console.info("# done");
      Qt.quit();
      return;
    }
    waited = 0;
    cases[index].start?.();
    poll.start();
  }

  Component.onCompleted: next()

  Timer {
    id: poll
    interval: 50
    repeat: true
    onTriggered: {
      const passed = root.cases[root.index].until();
      root.waited += interval;
      if (!passed && root.waited < 5000) return;
      stop();
      console.info((passed ? "ok " : "not ok ") + (root.index + 1) + " - " + root.cases[root.index].name);
      root.next();
    }
  }

  Connections {
    target: Plugins.get("watcher")
    function onTextChanged() {
      root.watched = root.watched.concat([target.text]);
    }
  }

  MenuModel {
    id: menu
  }
}
