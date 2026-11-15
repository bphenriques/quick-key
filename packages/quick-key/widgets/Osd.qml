pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// A slim bar at the right edge on a volume, device, brightness, layout or keep-awake change, so it never reads as a notification.
Scope {
  id: root

  // What is or was last shown, one of Config.popups.show; kept while the window closes.
  property string kind: ""

  // An unlisted pop-up never starts its service: the target is null.
  function listed(kind) {
    return Config.popups.show.includes(kind);
  }

  function show(newKind) {
    if (!listed(newKind)) return;
    kind = newKind;
    transient.show();
  }

  Transient {
    id: transient
    // Bound here, not read in show(): singletons start on first use, and this one must start with the shell.
    armed: Startup.settled
  }

  Fade {
    id: fade
    shown: transient.shown
  }

  Connections {
    target: root.listed("sink") || root.listed("source") ? Audio : null
    function onSinkVolumeChanged() { root.show("sink"); }
    function onSinkMutedChanged() { root.show("sink"); }
    function onSinkNameChanged() { root.show("sink"); }
    function onSourceVolumeChanged() { root.show("source"); }
    function onSourceMutedChanged() { root.show("source"); }
  }

  Connections {
    target: root.listed("brightness") ? Brightness : null
    function onPercentageChanged() { root.show("brightness"); }
  }

  Connections {
    target: root.listed("keyboardLayout") ? KeyboardLayout : null
    function onIndexChanged() { root.show("keyboardLayout"); }
  }

  Connections {
    target: root.listed("keepAwake") ? IdleInhibit : null
    function onEnabledChanged() { root.show("keepAwake"); }
  }

  LazyLoader {
    active: fade.loaded

    OverlayWindow {
      id: window

      readonly property bool metered: root.kind === "sink" || root.kind === "source" || root.kind === "brightness"
      readonly property bool muted: root.kind === "sink" ? Audio.sinkMuted
        : root.kind === "source" ? Audio.sourceMuted
        : root.kind === "keepAwake" ? !IdleInhibit.enabled
        : false
      readonly property string tone: muted ? "dim" : root.kind === "keepAwake" ? "primary" : "normal"
      readonly property string glyph: root.kind === "sink" ? (muted ? Glyphs.volumeOff : Glyphs.audioDevice(Audio.sinkType))
        : root.kind === "source" ? (muted ? Glyphs.microphoneOff : Glyphs.audioDevice(Audio.sourceType))
        : root.kind === "brightness" ? Glyphs.brightness(Brightness.percentage)
        : root.kind === "keepAwake" ? Glyphs.keepAwake
        : Glyphs.keyboard

      anchors.right: true
      margins.right: Config.theme.edgeMargin
      WlrLayershell.namespace: "osd"

      implicitWidth: metered ? bar.implicitWidth : pill.implicitWidth
      implicitHeight: metered ? bar.implicitHeight : pill.implicitHeight

      // A level: a vertical bar, the level above the icon.
      Surface {
        id: bar
        opacity: fade.value
        anchors.fill: parent
        visible: window.metered
        implicitWidth: Config.theme.osdIconSize + 2 * Config.theme.padding
        implicitHeight: levelColumn.implicitHeight + 2 * Config.theme.padding

        // The wheel adjusts the level shown: the volume directly, the backlight with brightness.adjust.
        WheelSteps {
          anchors.fill: parent
          hoverEnabled: true
          onContainsMouseChanged: transient.held = containsMouse
          onStepped: up => {
            if (root.kind !== "brightness") Audio.adjust(root.kind, up);
            else if (Config.brightness.adjust) Quickshell.execDetached(["sh", "-c", Config.brightness.adjust[up ? 1 : 0]]);
          }
        }

        Column {
          id: levelColumn
          anchors.centerIn: parent
          spacing: Config.theme.padding

          Meter {
            anchors.horizontalCenter: parent.horizontalCenter
            orientation: Qt.Vertical
            height: Config.theme.osdLength
            tone: window.muted ? "dim" : "primary"
            value: root.kind === "sink" ? Audio.sinkVolume
              : root.kind === "source" ? Audio.sourceVolume
              : Brightness.percentage / 100
          }

          Icon {
            anchors.horizontalCenter: parent.horizontalCenter
            size: Config.theme.osdIconSize
            tone: window.tone
            glyph: window.glyph
          }
        }
      }

      // A state without a level (layout, keep awake): a pill with the icon and what it is now.
      Pill {
        id: pill
        opacity: fade.value
        anchors.fill: parent
        visible: !window.metered
        padding: Config.theme.padding
        // The bar's radius, not the capsule: the two shapes swap as the kind changes, so they must agree.
        radius: Config.theme.radius

        Icon {
          anchors.verticalCenter: parent.verticalCenter
          tone: window.tone
          glyph: window.glyph
        }

        Label {
          id: value
          anchors.verticalCenter: parent.verticalCenter
          // As wide as the widest value, so the pill holds still as it changes.
          width: Math.max(3, ...Array.from(Config.keyboardLayout.labels).map(label => label.length)) * Metrics.cell
          tone: window.tone
          text: root.kind === "keyboardLayout" ? KeyboardLayout.label
            : IdleInhibit.enabled ? "on" : "off"
        }
      }
    }
  }
}
