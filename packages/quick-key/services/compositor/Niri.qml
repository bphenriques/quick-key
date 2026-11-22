pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io

// niri behind Compositor: layouts from its event stream, which replays on connect, outputs on request; `received` for plugins.
Singleton {
  id: root

  readonly property var layouts: internal.layouts
  readonly property int layoutIndex: internal.layoutIndex
  // The output of the focused workspace, by connector name.
  readonly property string focusedOutput: internal.outputs[internal.focused] ?? ""

  // Every event as niri sends it, for plugins that follow more of niri than the shell does.
  signal received(var event)
  signal outputsMoved

  QtObject {
    id: internal

    property var layouts: []
    property int layoutIndex: 0
    // Each workspace's output by its id, and the focused one's id.
    property var outputs: ({})
    // The outputs holding workspaces, joined, to tell when one turns on or off.
    property string on: ""
    property var focused: null

    function handle(event) {
      if (event.KeyboardLayoutsChanged) {
        layouts = event.KeyboardLayoutsChanged.keyboard_layouts.names;
        layoutIndex = event.KeyboardLayoutsChanged.keyboard_layouts.current_idx;
      } else if (event.KeyboardLayoutSwitched) {
        layoutIndex = event.KeyboardLayoutSwitched.idx;
      } else if (event.WorkspacesChanged) {
        const workspaces = event.WorkspacesChanged.workspaces;
        const outputs = {};
        for (const workspace of workspaces) outputs[workspace.id] = workspace.output;
        internal.outputs = outputs;
        // A screen turned on or off moves the workspaces: what reads the outputs (Compositor) reads them again.
        const on = [...new Set(workspaces.map(workspace => workspace.output))].sort().join();
        if (on !== internal.on) {
          internal.on = on;
          root.outputsMoved();
        }
        focused = workspaces.find(workspace => workspace.is_focused)?.id ?? focused;
      } else if (event.WorkspaceActivated?.focused) {
        focused = event.WorkspaceActivated.id;
      }
      root.received(event);
    }
  }

  // One request on its own connection, as `niri msg` does: the event stream's connection carries only events.
  function request(message, callback) {
    requestComponent.createObject(root, { message: JSON.stringify(message), callback: callback ?? null });
  }

  // Focuses a window of the app named, by its desktop entry or its name: an app id that is one, or ends with one (com.rtosta.zapzap for ZapZap); nothing when none is open.
  function focusApp(names) {
    const wanted = names.filter(name => name).map(name => String(name).toLowerCase());
    request("Windows", reply => {
      const window = reply.Windows.find(window => {
        const id = (window.app_id ?? "").toLowerCase();
        return wanted.some(name => id === name || id.endsWith("." + name));
      });
      if (window) request({ Action: { FocusWindow: { id: window.id } } });
    });
  }

  function switchLayout() {
    request({ Action: { SwitchLayout: { layout: "Next" } } });
  }

  // Calls back with the outputs connected and those on, each by connector name and by make, model and serial; one that is off has no logical size.
  function outputs(onRead) {
    request("Outputs", reply => {
      const all = Object.entries(reply.Outputs);
      const names = ([name, output]) => [name, `${output.make} ${output.model} ${output.serial ?? "Unknown"}`];
      onRead([].concat(...all.map(names)), [].concat(...all.filter(([, output]) => output.logical).map(names)));
    });
  }

  Component {
    id: requestComponent

    Socket {
      id: socket
      property string message
      property var callback
      // One that never connects or answers is dropped, rather than kept for good.
      property Timer expiry: Timer {
        interval: 5000
        running: true
        onTriggered: {
          console.warn("niri: no answer to", socket.message);
          socket.destroy();
        }
      }

      path: Quickshell.env("NIRI_SOCKET")
      connected: true
      onConnectedChanged: {
        if (connected) {
          write(message + "\n");
          flush();
        } else {
          destroy();
        }
      }

      parser: SplitParser {
        onRead: line => {
          const reply = JSON.parse(line);
          if (!reply.Ok) console.warn("niri: refused", socket.message + ":", JSON.stringify(reply.Err ?? reply));
          else if (socket.callback) socket.callback(reply.Ok);
          socket.connected = false;
        }
      }
    }
  }

  Socket {
    path: Quickshell.env("NIRI_SOCKET")
    connected: true
    onConnectedChanged: if (connected) write('"EventStream"\n')

    parser: SplitParser {
      onRead: line => internal.handle(JSON.parse(line))
    }
  }
}
