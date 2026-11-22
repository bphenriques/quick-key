pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import qs
import qs.services
import qs.services.compositor
import qs.ui

// When you move between windows or workspaces, the layout Minimap.qml draws; every column, since niri does not report scrolling.
Plugin {
  id: root

  readonly property bool shown: transient.shown
  views: ["Minimap.qml"]

  property bool overview: false
  // The focused output's workspaces and the columns around the active one, without titles, so it changes only with the layout.
  property var map: null

  Transient {
    id: transient
    armed: false
  }

  // niri's first layout is the state at start, not a move.
  onMapChanged: if (map !== null && !transient.armed) Qt.callLater(() => transient.armed = true)

  // You moved: focus went to another window or workspace. A window that opens or closes moves focus without it.
  function moved() {
    if (!overview) transient.show();
  }

  QtObject {
    id: tracked
    property var workspaces: ({})
    property var windows: ({})
    // The window focus was last on; a layer such as the menu taking the keyboard reports none, and giving it back the same one.
    property var focused: null
  }

  function columnsOf(workspace) {
    const columns = [];
    for (const window of Object.values(tracked.windows)) {
      const position = window.layout?.pos_in_scrolling_layout;
      if (!position || window.workspace_id !== workspace?.id) continue;
      const [column, row] = position;
      const [width, height] = window.layout.tile_size;
      if (!columns[column - 1]) columns[column - 1] = [];
      columns[column - 1][row - 1] = { appId: window.app_id ?? "", width: Math.round(width), height: Math.round(height), focused: window.id === workspace.active_window_id };
    }
    // Holes appear for a moment while windows move between columns.
    return Array.from(columns, column => (column ?? []).filter(window => window)).filter(column => column.length > 0);
  }

  function update() {
    const workspaces = Object.values(tracked.workspaces);
    const focused = workspaces.find(workspace => workspace.is_focused);
    if (!focused) return;
    const onOutput = workspaces.filter(workspace => workspace.output === focused.output).sort((a, b) => a.idx - b.idx);
    const index = onOutput.findIndex(workspace => workspace.is_active);
    const occupied = new Set(Object.values(tracked.windows).map(window => window.workspace_id));
    const next = {
      output: focused.output,
      workspaces: onOutput.filter(workspace => workspace.is_active || occupied.has(workspace.id)).map(workspace => ({ active: workspace.is_active })),
      above: columnsOf(onOutput[index - 1]),
      columns: columnsOf(onOutput[index]),
      below: columnsOf(onOutput[index + 1])
    };
    if (JSON.stringify(next) !== JSON.stringify(map)) map = next;
  }

  function byId(list) {
    const items = {};
    for (const item of list) items[item.id] = item;
    return items;
  }

  function handle(event) {
    if (event.WorkspacesChanged) {
      tracked.workspaces = byId(event.WorkspacesChanged.workspaces);
    } else if (event.WorkspaceActivated) {
      const activated = tracked.workspaces[event.WorkspaceActivated.id];
      for (const workspace of Object.values(tracked.workspaces)) {
        if (workspace.output === activated?.output) workspace.is_active = workspace.id === activated.id;
        if (event.WorkspaceActivated.focused) workspace.is_focused = workspace.id === activated?.id;
      }
    } else if (event.WorkspaceActiveWindowChanged) {
      const workspace = tracked.workspaces[event.WorkspaceActiveWindowChanged.workspace_id];
      if (workspace) workspace.active_window_id = event.WorkspaceActiveWindowChanged.active_window_id;
    } else if (event.WindowFocusChanged) {
      const id = event.WindowFocusChanged.id;
      if (id !== null && id !== tracked.focused) {
        tracked.focused = id;
        pendingMove.restart();
      }
      return;
    } else if (event.WindowsChanged) {
      tracked.windows = byId(event.WindowsChanged.windows);
    } else if (event.WindowOpenedOrChanged) {
      const window = event.WindowOpenedOrChanged.window;
      tracked.windows[window.id] = window;
    } else if (event.WindowClosed) {
      pendingMove.stop();
      delete tracked.windows[event.WindowClosed.id];
    } else if (event.WindowLayoutsChanged) {
      for (const [id, layout] of event.WindowLayoutsChanged.changes) if (tracked.windows[id]) tracked.windows[id].layout = layout;
    } else if (event.OverviewOpenedOrClosed) {
      overview = event.OverviewOpenedOrClosed.is_open;
      if (overview) transient.hide();
      return;
    } else {
      return;
    }
    update();
    if (event.WorkspaceActivated?.focused) pendingMove.restart();
  }

  // Closing a window moves focus first and reports the close right after: a move waits a moment to see whether it was one.
  Timer {
    id: pendingMove
    interval: 50
    onTriggered: root.moved()
  }

  Connections {
    target: Niri

    function onReceived(event) {
      root.handle(event);
    }
  }

}
