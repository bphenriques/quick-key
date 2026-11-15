pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.ui

// The map in the corner of the focused output while NiriMinimap shows it, sized by its settings.
Scope {
  id: view

  required property var plugin
  readonly property var settings: plugin.settings

  Fade {
    id: fade
    shown: view.plugin.shown
  }

  readonly property var screen: Quickshell.screens.find(screen => screen.name === view.plugin.map?.output) ?? null
  readonly property int gap: 2 * view.settings.borderWidth
  readonly property real dot: view.settings.height / 8
  readonly property real strip: view.settings.height / 5
  // Sized to mapHeight for the output's height, shrunk further if any of the three workspaces would pass maxWidth.
  readonly property real scale: {
    if (!screen || !view.plugin.map) return 0;
    let fit = view.settings.height / screen.height;
    for (const columns of [view.plugin.map.above, view.plugin.map.columns, view.plugin.map.below]) {
      const total = columns.reduce((sum, column) => sum + widthOf(column), 0);
      if (total > 0) fit = Math.min(fit, (view.settings.maxWidth - gap * (columns.length - 1)) / total);
    }
    return fit;
  }

  function widthOf(column) {
    return Math.max(...column.map(window => window.width));
  }

  // A window, its app's icon in the middle; the focused one outlined in the primary colour.
  component Tile: Rectangle {
    id: tile

    property bool focused: false
    property string appId: ""

    radius: Config.theme.itemRadius / 2
    color: Tone.surface(view.settings.opacity)
    border.width: view.settings.borderWidth
    border.color: Tone.color(focused ? "primary" : "dim")

    Icon {
      anchors.centerIn: parent
      visible: tile.appId !== ""
      size: Math.min(0.4 * view.settings.height, 0.6 * Math.min(tile.width, tile.height))
      source: tile.appId ? Quickshell.iconPath(DesktopEntries.heuristicLookup(tile.appId)?.icon ?? tile.appId, true) : ""
      glyph: Glyphs.window
      tone: tile.focused ? "normal" : "dim"
    }
  }

  // A neighbouring workspace: one block per column, without windows or icons; the column focus would land on is outlined.
  component Strip: Row {
    id: strip

    property var columns: []

    visible: columns.length > 0
    spacing: view.gap

    Repeater {
      model: strip.columns

      Tile {
        required property var modelData
        readonly property bool target: modelData.some(window => window.focused)

        width: view.widthOf(modelData) * view.scale
        height: view.strip
        focused: target
      }
    }
  }

  LazyLoader {
    active: fade.loaded && view.screen !== null

    OverlayWindow {
      screen: view.screen
      anchors.top: true
      anchors.left: true
      margins.top: Config.theme.edgeMargin
      margins.left: Config.theme.edgeMargin
      WlrLayershell.namespace: "niriMinimap"
      mask: Region {}

      implicitWidth: content.implicitWidth
      implicitHeight: content.implicitHeight

      Row {
        id: content
        opacity: fade.value
        spacing: Config.theme.spacing

        // niri stacks workspaces vertically; the active one is the long mark.
        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: view.dot

          Repeater {
            model: view.plugin.map.workspaces

            Rectangle {
              required property var modelData

              width: view.dot
              height: modelData.active ? 3 * view.dot : view.dot
              radius: view.dot / 2
              color: Tone.color(modelData.active ? "primary" : "dim")
            }
          }
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: view.gap

          Strip {
            columns: view.plugin.map.above
          }

          Row {
            spacing: view.gap

            Repeater {
              model: view.plugin.map.columns

              Column {
                id: column
                required property var modelData

                spacing: view.gap

                Repeater {
                  model: column.modelData

                  Tile {
                    required property var modelData

                    width: view.widthOf(column.modelData) * view.scale
                    height: modelData.height * view.scale
                    focused: modelData.focused
                    appId: modelData.appId
                  }
                }
              }
            }
          }

          Strip {
            columns: view.plugin.map.below
          }
        }
      }
    }
  }
}
