pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.Pipewire
import qs
import qs.ui

// Default output and input, and every device to pick from.
Singleton {
  id: root

  readonly property PwNode sink: Pipewire.defaultAudioSink
  readonly property PwNode source: Pipewire.defaultAudioSource

  // Outputs and inputs backed by hardware, internal first then by label: { node, kind, name, type, label }.
  readonly property var sinks: internal.devices.filter(device => device.kind === "sink")
  readonly property var sources: internal.devices.filter(device => device.kind === "source")

  // The type (headset, headphones, internal, external, microphone) picks the glyph.
  readonly property string sinkType: internal.sinkDevice?.type ?? ""
  readonly property string sourceType: internal.sourceDevice?.type ?? "microphone"
  readonly property string sinkName: internal.sinkDevice?.label || sink?.nickname || sink?.description || ""
  readonly property string sourceName: internal.sourceDevice?.label || source?.nickname || source?.description || ""
  readonly property bool sinkMuted: sink?.audio?.muted ?? false
  readonly property bool sourceMuted: source?.audio?.muted ?? false

  // What apps play, each a stream with its own volume; the one picked, which the stream actions change, else the first.
  readonly property var streams: internal.streams.filter(node => node.properties["application.name"])
  readonly property PwNode stream: streams.find(node => node.id === internal.picked) ?? streams[0] ?? null
  readonly property bool streamMuted: stream?.audio?.muted ?? false

  // A device's volume as said beside it: muted, else its percentage.
  function level(node) {
    return node?.audio?.muted ? Words.muted : Math.round((node?.audio?.volume ?? 0) * 100) + "%";
  }

  // A device's or stream's volume a step down or up (Config.audio.step), never past Config.audio.max; up never lowers one set above it elsewhere.
  function adjust(node, up) {
    if (!node?.audio) return;
    const step = Config.audio.step / 100;
    const next = Math.max(0, Math.min(Config.audio.max / 100, Math.round((node.audio.volume + (up ? step : -step)) / step) * step));
    node.audio.volume = up ? Math.max(node.audio.volume, next) : next;
  }

  // A volume as a meter fills, full at Config.audio.max when it allows more than 100%.
  function meter(node) {
    return (node?.audio?.volume ?? 0) * 100 / Math.max(100, Config.audio.max);
  }

  function toggleMute(node) {
    if (node?.audio) node.audio.muted = !node.audio.muted;
  }

  function pick(node) {
    internal.picked = node.id;
  }

  // WirePlumber moves the streams that follow the default.
  function select(device) {
    if (device.kind === "sink") Pipewire.preferredDefaultAudioSink = device.node;
    else Pipewire.preferredDefaultAudioSource = device.node;
  }

  // Form factor first; an output on USB, Bluetooth or HDMI is external.
  function type(node) {
    const formFactor = node.properties["device.form-factor"] ?? "";
    if (formFactor === "headset") return "headset";
    if (!node.isSink) return "microphone";
    if (formFactor === "headphone") return "headphones";
    const bus = node.properties["device.bus"] ?? "";
    return bus === "usb" || bus === "bluetooth" || node.name.includes("hdmi") ? "external" : "internal";
  }

  function describe(node) {
    const deviceType = type(node);
    const label = deviceType === "internal" ? Words.speakers : deviceType === "headphones" ? Words.headphones : node.nickname || node.description;
    return { node, kind: node.isSink ? "sink" : "source", name: node.name, type: deviceType, label };
  }

  QtObject {
    id: internal
    // A node's properties arrive once it is tracked; virtual ones have no device.
    readonly property var nodes: Pipewire.nodes.values.filter(node => !node.isStream && node.audio)
    // Playback streams; an app's carries its name, which loopbacks and filters lack.
    readonly property var streams: Pipewire.nodes.values.filter(node => node.isStream && node.isSink && node.audio)
    property int picked: -1
    readonly property var devices: nodes.filter(node => node.properties["device.id"]).map(node => root.describe(node))
      .sort((a, b) => a.kind.localeCompare(b.kind) || rank(a) - rank(b) || a.label.localeCompare(b.label))
    readonly property var sinkDevice: root.sinks.find(device => device.name === root.sink?.name) ?? null
    readonly property var sourceDevice: root.sources.find(device => device.name === root.source?.name) ?? null

    function rank(device) {
      return device.type === "internal" || device.type === "microphone" ? 0 : 1;
    }
  }

  PwObjectTracker {
    objects: internal.nodes.concat(internal.streams)
  }
}
