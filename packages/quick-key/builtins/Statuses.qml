pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// The built-in statuses by name; `status` and the header name one of these or a plugin.
Singleton {
  id: root

  readonly property var none: ({ text: "", detail: "" })

  // Each: glyph(), value(pinned, quiet) as { text, detail, glyphs }, and optionally tone(), detailChars, inLevel, and a meter() for its level, dim while muted(), sampled only while shown.
  readonly property var builtin: ({
    sink: {
      glyph: () => Audio.sinkMuted ? Glyphs.volumeOff : Glyphs.audioDevice(Audio.sinkType),
      value: pinned => !Audio.sink ? root.none : { text: pinned(Audio.sink.name, Audio.sinkName), detail: Audio.sinkMuted ? "muted" : Math.round(Audio.sinkVolume * 100) + "%" },
      // Room for "muted", so the glyph beside a volume holds still.
      detailChars: 5,
      meter: () => Audio.sinkVolume,
      muted: () => Audio.sinkMuted
    },
    source: {
      glyph: () => Audio.sourceMuted ? Glyphs.microphoneOff : Glyphs.audioDevice(Audio.sourceType),
      value: pinned => !Audio.source ? root.none : { text: pinned(Audio.source.name, Audio.sourceName), detail: Audio.sourceMuted ? "muted" : Math.round(Audio.sourceVolume * 100) + "%" },
      detailChars: 5,
      // The input moving as you speak, in its own level beside the volume.
      meter: () => Audio.sourceMuted ? 0 : Audio.sourceLevel,
      sampled: true
    },
    music: {
      glyph: () => Glyphs.music,
      value: () => !Music.present || !Music.title ? root.none : {
        text: Music.title + (Music.artist ? " · " + Music.artist : ""),
        detail: Music.playing ? "" : "paused",
        glyphs: [Music.repeat ? Glyphs.repeat : "", Music.shuffle ? Glyphs.shuffle : ""].filter(glyph => glyph)
      }
    },
    network: {
      glyph: () => Network.kind === "wifi" ? Glyphs.wifi : Network.kind === "wired" ? Glyphs.ethernet : Glyphs.disconnected,
      value: pinned => ({
        text: Network.kind === "wifi" ? pinned(Network.ssid, Network.ssid) : Network.kind === "wired" ? "Ethernet" : "Disconnected",
        detail: Network.wifiEnabled ? "" : "Wi-Fi off"
      })
    },
    bluetooth: {
      glyph: () => !Bluez.enabled ? Glyphs.bluetoothOff : Bluez.connected.length ? Glyphs.bluetoothConnected : Glyphs.bluetooth,
      value: pinned => {
        if (!Bluez.present) return root.none;
        if (!Bluez.enabled) return { text: "", detail: "off" };
        const [device, ...others] = Bluez.connected;
        if (!device) return { text: "No device connected", detail: "" };
        if (others.length) return { text: Bluez.connected.length + " devices connected", detail: "" };
        return { text: pinned(device.address, device.name), detail: device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "" };
      }
    },
    tray: {
      glyph: () => Glyphs.tray,
      value: pinned => ({ text: Tray.items.map(app => pinned(app.id, app.title || app.id)).join(", "), detail: "" }),
      // Its value is the list its level already shows.
      inLevel: false
    },
    brightness: {
      glyph: () => Glyphs.brightness(Brightness.percentage),
      value: () => !Brightness.present ? root.none : { text: "", detail: Brightness.lit ? Brightness.percentage + "%" : "off" },
      meter: () => Brightness.lit ? Brightness.percentage / 100 : 0
    },
    calendar: {
      glyph: () => Glyphs.calendar,
      value: (pinned, quiet) => root.calendar(quiet)
    },
    battery: {
      glyph: () => Power.present ? Glyphs.battery(Power.percentage, Power.pluggedIn) : "",
      value: () => ({ text: Power.present ? Power.percentage + "%" : "", detail: "" }),
      tone: () => Power.level === "critical" ? "alert" : Power.level === "low" ? "warning" : ""
    },
    keyboardLayout: {
      glyph: () => Glyphs.keyboard,
      value: () => ({ text: KeyboardLayout.label || KeyboardLayout.name, detail: "" })
    },
    keepAwake: {
      glyph: () => Glyphs.keepAwake,
      value: () => root.none,
      tone: () => IdleInhibit.enabled ? "primary" : ""
    }
  })

  // In a level's header how old the events are; on a row the next event, and when.
  function calendar(quiet) {
    if (!Calendar.enabled) return none;
    if (quiet) {
      const updated = Calendar.updated;
      return {
        text: "",
        // Its age even after a failed sync, the line under the legend saying why: the events shown are that old.
        detail: Calendar.syncing ? "syncing…" : !updated ? ""
          : "updated " + Clock.format(updated, updated.toDateString() === Clock.date.toDateString() ? "%H:%M" : "%-d %b %H:%M")
      };
    }
    const next = Calendar.next;
    if (!next) return none;
    const today = next.start.toDateString() === Clock.date.toDateString() || next.start < Clock.date;
    const when = next.allDay ? (today ? "today" : Clock.format(next.start, "%a")) : Clock.format(next.start, today ? "%H:%M" : "%a %H:%M");
    return { text: next.title, detail: when };
  }
}
