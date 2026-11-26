pragma Singleton

import QtQuick
import Quickshell
import qs
import qs.services
import qs.ui

// Built-in statuses by name; a table without a prototype, so no name every object inherits (toString) is one.
Singleton {
  id: root

  // Each: glyph(), fields(pinned), names (the fields a format may name), value(fields) as { text, detail, glyphs }; optional fieldTones(), tone(), phase(), strong, meter() (below 0, none), muted(), adjust (the pair action the OSD wheel runs), popup and popupWidth (the OSD pill text and its widest), change() (what is worth a pop-up), ready() (its first value is state, not a change), brief (its value beside its icon in a bar).
  readonly property var builtin: Object.assign(Object.create(null), {
    // The default audio output.
    sink: {
      names: ["device", "volume"],
      glyph: () => Audio.sinkMuted ? Glyphs.volumeOff : Glyphs.audioDevice(Audio.sinkType),
      fields: pinned => !Audio.sink ? {} : { device: pinned(Audio.sink.name, Audio.sinkName), volume: Audio.level(Audio.sink) },
      format: "{device}|{volume}",
      meter: () => Audio.meter(Audio.sink),
      muted: () => Audio.sinkMuted,
      adjust: "sinkVolume",
      ready: () => Audio.sink?.ready ?? false
    },
    // The default audio input, the microphone.
    source: {
      names: ["device", "volume"],
      glyph: () => Audio.sourceMuted ? Glyphs.microphoneOff : Glyphs.audioDevice(Audio.sourceType),
      fields: pinned => !Audio.source ? {} : { device: pinned(Audio.source.name, Audio.sourceName), volume: Audio.level(Audio.source) },
      format: "{device}|{volume}",
      meter: () => Audio.meter(Audio.source),
      muted: () => Audio.sourceMuted,
      adjust: "sourceVolume",
      ready: () => Audio.source?.ready ?? false
    },
    // Its glyph says whether it plays; with nothing playing it says so, which reads as state rather than something missing.
    music: {
      names: ["song", "title", "artist", "state"],
      glyph: () => !Music.present || !Music.title ? Glyphs.musicOff : Music.playing ? Glyphs.music : Glyphs.musicPaused,
      fields: () => !Music.present || !Music.title ? { song: Words.noSong }
        : { song: Music.title + (Music.artist ? " · " + Music.artist : ""), title: Music.title, artist: Music.artist, state: Music.playing ? "" : Words.paused },
      value: fields => ({
        text: fields.song,
        detail: "",
        glyphs: !fields.title ? [] : [Music.repeat ? Glyphs.repeat : "", Music.shuffle ? Glyphs.shuffle : ""].filter(glyph => glyph)
      })
    },
    network: {
      names: ["name", "internet", "wifi"],
      glyph: () => Network.kind === "wifi" ? Glyphs.wifiSignal(Network.strength, Network.limited) : Network.kind === "wired" ? Glyphs.ethernet : Glyphs.disconnected,
      fields: pinned => ({
        name: Network.kind === "wifi" ? pinned(Network.ssid, Network.ssid) : Network.kind === "wired" ? Words.ethernet : Words.disconnected,
        // Off only says why there is no connection: wired, it is beside the point.
        wifi: Network.wifiEnabled || Network.kind === "wired" ? "" : Words.wifiOff,
        internet: Network.limited ? Words.noInternet : ""
      }),
      format: "{name}|{internet} {wifi}",
      tone: () => Network.limited ? "warning" : "",
      // A pop-up as the connection changes, not as its signal does.
      change: () => [Network.kind, Network.ssid, Network.limited, Network.wifiEnabled]
    },
    bluetooth: {
      names: ["device", "state", "battery"],
      glyph: () => !Bluez.enabled ? Glyphs.bluetoothOff : Bluez.connected.length ? Glyphs.bluetoothConnected : Glyphs.bluetooth,
      fields: pinned => {
        if (!Bluez.present) return {};
        if (!Bluez.enabled) return { state: Words.off };
        const [device, ...others] = Bluez.connected;
        if (!device) return { device: Words.noDevice };
        if (others.length) return { device: Words.devicesConnected(Bluez.connected.length) };
        return { device: pinned(device.address, device.name), battery: device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "" };
      },
      format: "{device}|{state}{battery}",
      // A pop-up as it powers on or off or a device comes or goes, not at every percent of a headset's battery.
      change: () => [Bluez.enabled, Bluez.connected.map(device => device.address)],
      ready: () => Bluez.present
    },
    // The backlight's level; nothing while the output it lights is off.
    brightness: {
      names: ["level"],
      // Unlit, no level to report, not even in its glyph: the row dims for that, "off" would read as the screen being off, and a level changing unseen is no change to pop up.
      glyph: () => Glyphs.brightness(Brightness.lit ? Brightness.percentage : 0),
      fields: () => !Brightness.lit ? {} : { level: Brightness.percentage + "%" },
      format: "|{level}",
      meter: () => Brightness.lit ? Brightness.percentage / 100 : -1,
      adjust: "brightness",
      ready: () => Brightness.ready
    },
    // When the next event in calendar.file is; `more` is how many more start today (`+2`), `updated` how old the events are.
    calendar: {
      names: ["title", "when", "more", "updated"],
      glyph: () => Glyphs.calendar,
      fields: () => root.calendar(),
      phase: () => Calendar.syncing ? "working" : Calendar.error ? "error" : "idle",
      // A sync older than calendar.staleAfter warns, a format showing it or not.
      fieldTones: () => ({ updated: !Calendar.syncing && Clock.stale(Calendar.updated, Config.calendar.staleAfter) ? "warning" : "" }),
      format: "|{when}"
    },
    clock: {
      names: ["date"],
      glyph: () => Glyphs.calendar,
      fields: () => ({ date: Clock.text }),
      // The bar's anchor: bold, and not dimmed with the rest.
      strong: true,
      format: "{date}"
    },
    battery: {
      names: ["level"],
      glyph: () => Power.present ? Glyphs.battery(Power.percentage, Power.pluggedIn) : "",
      fields: () => !Power.present ? {} : { level: Power.percentage + "%" },
      format: "{level}",
      tone: () => Power.level === "critical" ? "alert" : Power.level === "low" ? "warning" : "",
      // A pop-up when it is plugged in or out, not at every percent; a low charge warns through battery.warn instead.
      change: () => Power.present && Power.pluggedIn,
      ready: () => Power.present
    },
    // The layout's label; with one layout nothing, as it can never switch.
    keyboardLayout: {
      names: ["layout"],
      glyph: () => KeyboardLayout.names.length > 1 ? Glyphs.keyboard : "",
      brief: true,
      fields: () => KeyboardLayout.names.length > 1 ? { layout: KeyboardLayout.label || KeyboardLayout.name } : {},
      format: "{layout}",
      popupWidth: () => Math.max(3, ...Array.from(Config.keyboardLayout.labels).map(label => label.length)),
      ready: () => KeyboardLayout.names.length > 0
    },
    // Where its daemon is (Power.profilesPresent); else nothing, so the row dims and a bar hides it.
    powerProfile: {
      names: ["profile"],
      glyph: () => Glyphs.powerProfiles[Power.profile] ?? "",
      fields: () => Power.profile ? { profile: Words.powerProfiles[Power.profile].toLowerCase() } : {},
      format: "|{profile}"
    },
    keepAwake: {
      names: [],
      glyph: () => Glyphs.keepAwake,
      fields: () => ({}),
      format: "",
      tone: () => KeepAwake.enabled ? "primary" : "",
      muted: () => !KeepAwake.enabled,
      popup: () => Words.keepAwakeState(KeepAwake.enabled),
      popupWidth: () => Words.keepAwakeState(false).length
    }
  })

  // What a name neither built in nor a plugin's shows: nothing; change, when set, is all a pop-up watches.
  readonly property var none: ({ glyph: "", text: "", detail: "", glyphs: [], fields: {}, fieldTones: {}, tone: "", phase: "idle", active: false,
    strong: false, brief: false, meter: -1, muted: false, popup: "", popupWidth: 0, change: null, ready: false, adjust: "" })

  // A format with each {field} replaced; a field without a value leaves nothing.
  function formatted(format, fields) {
    return format.replace(/\{(\w+)\}/g, (_, name) => fields[name] ?? "").trim();
  }

  // A status by name, a built-in's or else the plugin's, in one shape, none's: what a bar, a row and the pop-up all show for it.
  function of(name, pinned = (id, label) => label) {
    const status = builtin[name];
    const plugin = status ? null : Plugins.get(name);
    if (plugin) return Object.assign({}, none, {
      glyph: plugin.glyph, text: plugin.text, detail: plugin.detail, glyphs: Array.from(plugin.glyphs), fieldTones: plugin.fieldTones,
      fields: Object.assign({ text: plugin.text, detail: plugin.detail }, plugin.fields), tone: plugin.tone, phase: plugin.phase, active: plugin.active,
      popup: [plugin.text, plugin.detail].filter(part => part).join(" "),
      ready: plugin.ready
    });
    if (!status) return none;
    const fields = status.fields(pinned);
    const own = value(status, fields, "");
    const call = key => status[key] ? status[key]() : none[key];
    return Object.assign({}, none, own, {
      glyph: status.glyph(), fields, fieldTones: call("fieldTones"), tone: call("tone"), phase: call("phase"), meter: call("meter"), muted: call("muted"),
      strong: !!status.strong, brief: !!status.brief, popup: status.popup ? status.popup() : own.text, popupWidth: call("popupWidth"),
      change: call("change"), ready: !status.ready || status.ready(), adjust: status.adjust ?? ""
    });
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
    // An all-day event under way is today's, a timed one says when it ends.
    const when = next.allDay ? Clock.day(next.start < Clock.date ? Clock.date : next.start)
      : next.start <= Clock.date ? Words.until(Clock.when(next.end, true)) : Clock.when(next.start, true);
    return { title: next.title, when, more: Calendar.more ? "+" + Calendar.more : "", updated };
  }
}
