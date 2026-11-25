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
  readonly property var islands: menu.layout.map(name => ({ input: inputIsland, body: bodyIsland, bar: barIsland })[name] ?? Array.from(pinnedIslands.instances).find(island => island.name === name)).filter(island => island)

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
    empty: root.menu.inputEmpty
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
    minimumHeight: root.menu.body.minHeight + 2 * padding
    onClicked: root.menu.focusIsland("body")
    // As Escape does, but never closing the top level.
    onSecondaryClicked: if (root.menu.level) root.menu.stepBack()
    content: MenuBody {
      menu: root.menu
      level: root.menu.body
    }
  }

  // Each pinned level showing, drawn as the body draws its own, as wide as its entry; never shrinking while its layout shows, made anew as it comes back.
  Variants {
    id: pinnedIslands
    model: root.menu.pinnedLevels

    Island {
      id: pin
      required property LevelModel modelData
      // Its level goes first as a layout changes.
      name: modelData?.island ?? ""
      width: modelData?.width ?? -1
      holdKey: root.menu.visit
      onClicked: root.menu.focusIsland(modelData.island)
      content: MenuBody {
        menu: root.menu
        level: pin.modelData
      }
    }
  }

  Island {
    id: barIsland
    name: "bar"
    empty: root.menu.barEmpty
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
