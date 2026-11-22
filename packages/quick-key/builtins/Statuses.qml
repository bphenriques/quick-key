pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// The built-in statuses by name; `status` and the header name one of these or a plugin; a table without a prototype, so no name every object inherits (toString) is one.
Singleton {
  id: root

  // Each: glyph(), fields(pinned) by name, and its value over them: `format` as an entry's is read, else value(fields) as { text, detail, glyphs } (music, which adds its modes), and optionally tone(), busy() (a spinner on a bar icon showing it), strong (bold, never dimmed in a bar), and a meter() for its level (below 0, none), dim while muted(). adjust names the pair action the OSD's wheel runs; popup is the OSD pill's text (else it shows the value's text) and popupWidth the characters it must hold at most (else the text's own).
  readonly property var builtin: Object.assign(Object.create(null), {
    sink: {
      glyph: () => Audio.sinkMuted ? Glyphs.volumeOff : Glyphs.audioDevice(Audio.sinkType),
      fields: pinned => !Audio.sink ? {} : { device: pinned(Audio.sink.name, Audio.sinkName), volume: Audio.level(Audio.sink) },
      format: "{device}|{volume}",
      meter: () => Audio.sinkVolume,
      muted: () => Audio.sinkMuted,
      adjust: "sinkVolume"
    },
    source: {
      glyph: () => Audio.sourceMuted ? Glyphs.microphoneOff : Glyphs.audioDevice(Audio.sourceType),
      fields: pinned => !Audio.source ? {} : { device: pinned(Audio.source.name, Audio.sourceName), volume: Audio.level(Audio.source) },
      format: "{device}|{volume}",
      meter: () => Audio.sourceVolume,
      muted: () => Audio.sourceMuted,
      adjust: "sourceVolume"
    },
    // Its glyph says whether it plays; with nothing playing it says so, which reads as state rather than something missing.
    music: {
      glyph: () => !Music.present || !Music.title ? Glyphs.musicOff : Music.playing ? Glyphs.music : Glyphs.musicPaused,
      fields: () => !Music.present || !Music.title ? { song: Words.noSong } : { song: Music.title + (Music.artist ? " · " + Music.artist : ""), title: Music.title, artist: Music.artist, state: Music.playing ? "" : Words.paused },
      value: fields => ({
        text: fields.song,
        detail: "",
        glyphs: !fields.title ? [] : [Music.repeat ? Glyphs.repeat : "", Music.shuffle ? Glyphs.shuffle : ""].filter(glyph => glyph)
      })
    },
    network: {
      glyph: () => Network.kind === "wifi" ? Glyphs.wifi : Network.kind === "wired" ? Glyphs.ethernet : Glyphs.disconnected,
      fields: pinned => ({
        name: Network.kind === "wifi" ? pinned(Network.ssid, Network.ssid) : Network.kind === "wired" ? Words.ethernet : Words.disconnected,
        wifi: Network.wifiEnabled ? "" : Words.wifiOff
      }),
      format: "{name}|{wifi}"
    },
    bluetooth: {
      glyph: () => !Bluez.enabled ? Glyphs.bluetoothOff : Bluez.connected.length ? Glyphs.bluetoothConnected : Glyphs.bluetooth,
      fields: pinned => {
        if (!Bluez.present) return {};
        if (!Bluez.enabled) return { state: Words.off };
        const [device, ...others] = Bluez.connected;
        if (!device) return { device: Words.noDevice };
        if (others.length) return { device: Words.devicesConnected(Bluez.connected.length) };
        return { device: pinned(device.address, device.name), battery: device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "" };
      },
      format: "{device}|{state}{battery}"
    },
    brightness: {
      // Unlit, no level to report, not even in its glyph: the row dims for that, "off" would read as the screen being off, and a level changing unseen is no change to pop up.
      glyph: () => Glyphs.brightness(Brightness.lit ? Brightness.percentage : 0),
      fields: () => !Brightness.lit ? {} : { level: Brightness.percentage + "%" },
      format: "|{level}",
      meter: () => Brightness.lit ? Brightness.percentage / 100 : -1,
      adjust: "brightness"
    },
    calendar: {
      glyph: () => Glyphs.calendar,
      fields: () => root.calendar(),
      busy: () => Calendar.syncing,
      // A sync older than calendar.staleAfter warns, a format showing it or not.
      fieldTones: () => ({ updated: !Calendar.syncing && Clock.stale(Calendar.updated, Config.calendar.staleAfter) ? "warning" : "" }),
      format: "|{when}"
    },
    clock: {
      glyph: () => Glyphs.calendar,
      fields: () => ({ date: Clock.text }),
      // The bar's anchor: bold, and not dimmed with the rest.
      strong: true,
      format: "{date}"
    },
    battery: {
      glyph: () => Power.present ? Glyphs.battery(Power.percentage, Power.pluggedIn) : "",
      fields: () => !Power.present ? {} : { level: Power.percentage + "%" },
      format: "{level}",
      tone: () => Power.level === "critical" ? "alert" : Power.level === "low" ? "warning" : ""
    },
    keyboardLayout: {
      glyph: () => Glyphs.keyboard,
      fields: () => ({ layout: KeyboardLayout.label || KeyboardLayout.name }),
      format: "{layout}",
      popupWidth: () => Math.max(3, ...Array.from(Config.keyboardLayout.labels).map(label => label.length))
    },
    keepAwake: {
      glyph: () => Glyphs.keepAwake,
      fields: () => ({}),
      format: "",
      tone: () => KeepAwake.enabled ? "primary" : "",
      muted: () => !KeepAwake.enabled,
      popup: () => Words.keepAwakeState(KeepAwake.enabled),
      popupWidth: () => Words.keepAwakeState(false).length
    }
  })

  // A format with each {field} replaced; a field without a value leaves nothing.
  function formatted(format, fields) {
    return format.replace(/\{(\w+)\}/g, (_, name) => fields[name] ?? "").trim();
  }

  // A status's value over its fields, { text, detail, glyphs }: an entry's format over the status's own, `|` before the detail; with neither, its value().
  function value(status, fields, format) {
    const shape = format || status.format;
    if (shape == null) return status.value(fields);
    const [text, detail] = shape.split("|");
    return { text: formatted(text, fields), detail: formatted(detail ?? "", fields) };
  }

  // The next event and when, and how old the events are: their age even after a failed sync, the line under the legend saying why.
  function calendar() {
    if (!Calendar.enabled) return {};
    const updated = Calendar.syncing ? Words.syncing : Calendar.updated ? Words.updated(Clock.when(Calendar.updated, true)) : "";
    const next = Calendar.next;
    if (!next) return { updated };
    // An all-day event under way is today's.
    const when = next.allDay ? Clock.day(next.start < Clock.date ? Clock.date : next.start) : Clock.when(next.start, true);
    return { title: next.title, when, updated };
  }
}
