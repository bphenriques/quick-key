pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Quickshell
import Quickshell.Io
import qs
import qs.ui

Scope {
  id: root

  readonly property MenuModel menu: MenuModel {}
  // menu.layout's islands, top to bottom.
  readonly property var islands: menu.layout.map(name => ({ input: inputIsland, body: bodyIsland, bar: barIsland })[name] ?? Array.from(pins.instances).find(pin => pin.name === name)).filter(island => island)

  function modifier(event) {
    if (event.key === Qt.Key_Control) return "Ctrl";
    if (event.key === Qt.Key_Super_L || event.key === Qt.Key_Super_R || event.key === Qt.Key_Meta) return "Super";
    return "";
  }

  Component {
    id: statuses

    HeaderSlot {
      implicitWidth: Layout.preferredWidth
      menu: root.menu
      alignment: Qt.AlignRight
      items: root.menu.barOf(root.menu.topBar.right)
    }
  }

  Binding {
    target: Panels
    property: "statuses"
    value: statuses
  }

  IpcHandler {
    target: "menu"

    function toggle(): void {
      root.menu.toggle();
    }

    function toggleEntry(key: string): void {
      root.menu.toggleEntry(key);
    }

    function press(path: string): bool {
      return root.menu.press(path);
    }

    function keys(): string {
      return root.menu.keyMap();
    }
  }

  Timer {
    id: held
    property string modifier
    interval: 1000
    onTriggered: root.menu.hold(modifier)
  }

  Stack {
    id: stack
    shown: root.menu.open
    namespace: "menu"
    width: root.menu.body.width
    focus: root.menu.inputFocused || root.menu.focused.filtering ? "input" : "body"
    onDismissed: root.menu.hide()
    onKeyPressed: event => {
      if (root.modifier(event) && !event.isAutoRepeat) {
        held.modifier = root.modifier(event);
        held.restart();
      }
      event.accepted = root.menu.handleKey(event);
    }
    onKeyReleased: event => {
      if (!root.modifier(event)) return;
      held.stop();
      root.menu.hold("");
    }

    islands: root.islands
  }

  // The focused island's input; filtering, the filter takes it, the input waiting under it. It never shrinks within its visit.
  Island {
    id: inputIsland
    name: "input"
    shown: root.menu.input.input !== null || root.menu.focused.filtering
    holdKey: root.menu.input.visit
    padding: Config.theme.padding / 2
    // As a row's content is, so its key column lines up with the body's keys.
    inset: Metrics.itemPaddingX
    content: MenuInput {
      menu: root.menu
    }
  }

  Island {
    id: bodyIsland
    name: "body"
    cut: true
    onClicked: root.menu.focusIsland("body")
    // As Escape does, but never closing the top level.
    onSecondaryClicked: if (root.menu.level) root.menu.stepBack()
    content: MenuBody {
      menu: root.menu
      level: root.menu.body
    }
  }

  // Each pinned level, drawn as the body draws its own, as wide as its entry; never shrinking while the menu shows.
  Variants {
    id: pins
    model: root.menu.pinned

    Island {
      id: pin
      required property string modelData
      readonly property LevelModel level: root.menu.modelOf(modelData)
      name: modelData
      width: level?.width ?? -1
      holdKey: root.menu.visit
      onClicked: root.menu.focusIsland(modelData)
      content: MenuBody {
        menu: root.menu
        level: pin.level
      }
    }
  }

  Island {
    id: barIsland
    name: "bar"
    shown: root.menu.barShown
    split: Config.menu.splitBar
    padding: Config.theme.padding / 4
    // At least a padded line, so a level's bar without the clock is as tall as the top level's and the body holds still.
    minimumHeight: Metrics.line + 2 * Metrics.itemPaddingY + Config.theme.padding / 2
    content: MenuHeader {
      menu: root.menu
      room: stack.room - 2 * Config.theme.padding
      onPicked: key => root.menu.focused.filtering ? (key === "Escape" ? root.menu.input.escaped() : root.menu.filterKey(key)) : root.menu.handleName(key) || root.menu.cursorKey(key)
    }
  }
}
