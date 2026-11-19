pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The built-in statuses by name; `status` and the header name one of these or a plugin.
Singleton {
  id: root

  // Each: glyph(), fields(pinned) by name for an entry's `format`, value(fields) as { text, detail, glyphs } when it has none, and optionally tone(), strong (bold, never dimmed in a bar), and a meter() for its level (below 0, none), dim while muted().
  readonly property var builtin: ({
    sink: {
      glyph: () => Audio.sinkMuted ? Glyphs.volumeOff : Glyphs.audioDevice(Audio.sinkType),
      fields: pinned => !Audio.sink ? {} : { device: pinned(Audio.sink.name, Audio.sinkName), volume: Audio.sinkMuted ? "muted" : Math.round(Audio.sinkVolume * 100) + "%" },
      value: fields => ({ text: fields.device ?? "", detail: fields.volume ?? "" }),
      meter: () => Audio.sinkVolume,
      muted: () => Audio.sinkMuted
    },
    source: {
      glyph: () => Audio.sourceMuted ? Glyphs.microphoneOff : Glyphs.audioDevice(Audio.sourceType),
      fields: pinned => !Audio.source ? {} : { device: pinned(Audio.source.name, Audio.sourceName), volume: Audio.sourceMuted ? "muted" : Math.round(Audio.sourceVolume * 100) + "%" },
      value: fields => ({ text: fields.device ?? "", detail: fields.volume ?? "" }),
      meter: () => Audio.sourceVolume,
      muted: () => Audio.sourceMuted
    },
    // Its glyph says whether it plays; with nothing playing it says so, which reads as state rather than something missing.
    music: {
      glyph: () => !Music.present || !Music.title ? Glyphs.musicOff : Music.playing ? Glyphs.music : Glyphs.musicPaused,
      fields: () => !Music.present || !Music.title ? { song: "No song playing" } : { song: Music.title + (Music.artist ? " · " + Music.artist : ""), title: Music.title, artist: Music.artist, state: Music.playing ? "" : "paused" },
      value: fields => ({
        text: fields.song,
        detail: "",
        glyphs: !fields.title ? [] : [Music.repeat ? Glyphs.repeat : "", Music.shuffle ? Glyphs.shuffle : ""].filter(glyph => glyph)
      })
    },
    network: {
      glyph: () => Network.kind === "wifi" ? Glyphs.wifi : Network.kind === "wired" ? Glyphs.ethernet : Glyphs.disconnected,
      fields: pinned => ({
        name: Network.kind === "wifi" ? pinned(Network.ssid, Network.ssid) : Network.kind === "wired" ? "Ethernet" : "Disconnected",
        wifi: Network.wifiEnabled ? "" : "Wi-Fi off"
      }),
      value: fields => ({ text: fields.name, detail: fields.wifi })
    },
    bluetooth: {
      glyph: () => !Bluez.enabled ? Glyphs.bluetoothOff : Bluez.connected.length ? Glyphs.bluetoothConnected : Glyphs.bluetooth,
      fields: pinned => {
        if (!Bluez.present) return {};
        if (!Bluez.enabled) return { state: "off" };
        const [device, ...others] = Bluez.connected;
        if (!device) return { device: "No device connected" };
        if (others.length) return { device: Bluez.connected.length + " devices connected" };
        return { device: pinned(device.address, device.name), battery: device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "" };
      },
      value: fields => ({ text: fields.device ?? "", detail: fields.state ?? fields.battery ?? "" })
    },
    brightness: {
      glyph: () => Glyphs.brightness(Brightness.percentage),
      // Unlit, no backlight to report: the row dims for that, and "off" would read as the screen being off.
      fields: () => !Brightness.lit ? {} : { level: Brightness.percentage + "%" },
      value: fields => ({ text: "", detail: fields.level ?? "" }),
      meter: () => Brightness.lit ? Brightness.percentage / 100 : -1
    },
    calendar: {
      glyph: () => Glyphs.calendar,
      fields: () => root.calendar(),
      // A sync older than calendar.staleAfter warns, a format showing it or not.
      fieldTones: () => ({ updated: !Calendar.syncing && Calendar.updated && Clock.date - Calendar.updated >= Config.calendar.staleAfter * 60000 ? "warning" : "" }),
      value: fields => ({ text: "", detail: fields.when ?? "" })
    },
    clock: {
      glyph: () => Glyphs.calendar,
      fields: () => ({ date: Clock.text }),
      // The bar's anchor: bold, and not dimmed with the rest.
      strong: true,
      value: fields => ({ text: fields.date, detail: "" })
    },
    battery: {
      glyph: () => Power.present ? Glyphs.battery(Power.percentage, Power.pluggedIn) : "",
      fields: () => !Power.present ? {} : { level: Power.percentage + "%" },
      value: fields => ({ text: fields.level ?? "", detail: "" }),
      tone: () => Power.level === "critical" ? "alert" : Power.level === "low" ? "warning" : ""
    },
    keyboardLayout: {
      glyph: () => Glyphs.keyboard,
      fields: () => ({ layout: KeyboardLayout.label || KeyboardLayout.name }),
      value: fields => ({ text: fields.layout, detail: "" })
    },
    keepAwake: {
      glyph: () => Glyphs.keepAwake,
      fields: () => ({}),
      value: () => ({ text: "", detail: "" }),
      tone: () => IdleInhibit.enabled ? "primary" : ""
    }
  })

  // A format with each {field} replaced; a field without a value leaves nothing.
  function formatted(format, fields) {
    return format.replace(/\{(\w+)\}/g, (_, name) => fields[name] ?? "").trim();
  }

  // The next event and when, and how old the events are: their age even after a failed sync, the line under the legend saying why.
  function calendar() {
    if (!Calendar.enabled) return {};
    const updated = Calendar.syncing ? Words.syncing : Calendar.updated ? "updated " + Clock.stamp(Calendar.updated) : "";
    const next = Calendar.next;
    if (!next) return { updated };
    const today = next.start.toDateString() === Clock.date.toDateString() || next.start < Clock.date;
    const when = next.allDay ? (today ? "today" : Clock.format(next.start, "%a")) : Clock.format(next.start, today ? "%H:%M" : "%a %H:%M");
    return { title: next.title, when, updated };
  }
}
