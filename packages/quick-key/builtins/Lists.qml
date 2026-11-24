pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// Built-in lists by name; no prototype, as in Statuses.qml.
Singleton {
  id: root

  // Wi-Fi scans while the level on top lists its networks, so those coming into range show.
  readonly property bool scanning: Panels.top?.level?.entry?.list === "wifi"
  onScanningChanged: Network.scan(scanning)

  // Each: items() as { id, desc, select, closes, detail, meter, adjust(up) for the wheel, ... }, the icon a pin shows while absent, why it is empty, extra keys.
  readonly property var builtin: Object.assign(Object.create(null), {
    tray: {
      icon: Glyphs.tray,
      empty: () => Words.emptyTray,
      legend: [{ key: "Alt+digit", what: Words.menu }],
      items: () => Tray.items.map(app => ({ id: app.id, desc: app.title || app.id, image: app.icon, app, closes: true, select: () => app.activate() }))
    },
    wifi: {
      icon: Glyphs.wifi,
      empty: () => Network.wifiEnabled ? Words.emptyNetworks : Words.wifiOff,
      items: () => Network.known.map(network => ({
        id: network.name, desc: network.name, icon: Glyphs.wifi, active: network.connected, busy: network.stateChanging, select: () => root.toggle(network)
      }))
    },
    bluetooth: {
      icon: Glyphs.bluetooth,
      empty: () => !Bluez.present ? Words.emptyNoAdapter : Bluez.enabled ? Words.emptyNoPaired : Words.emptyBluetoothOff,
      items: () => !Bluez.enabled ? [] : Bluez.paired.map(device => ({
        id: device.address,
        desc: device.name,
        icon: Glyphs.bluetooth,
        active: device.connected,
        busy: Bluez.changing(device),
        detail: device.connected && device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "",
        select: () => root.toggle(device)
      })).sort((a, b) => a.desc.localeCompare(b.desc))
    },
    // The power profiles its daemon offers, the one in use lit; a digit switches to one.
    powerProfiles: {
      icon: Glyphs.powerProfiles.balanced,
      empty: () => Words.noPowerProfiles,
      items: () => Power.profiles.map(name => ({ id: name, desc: Words.powerProfiles[name], icon: Glyphs.powerProfiles[name], active: name === Power.profile, select: () => Power.setProfile(name) }))
    },
    sinks: {
      icon: Glyphs.audioDevice("external"),
      empty: () => Words.emptyOutputs,
      items: () => root.audio(Audio.sinks, Audio.sink?.name)
    },
    sources: {
      icon: Glyphs.microphone,
      empty: () => Words.emptyInputs,
      items: () => root.audio(Audio.sources, Audio.source?.name)
    },
    // What apps play: a digit picks the one the stream actions change.
    streams: {
      icon: Glyphs.volume,
      empty: () => Words.emptyStreams,
      items: () => Audio.streams.map(node => root.stream(node, Audio.stream))
    }
  })

  // A plugin's item's fields that take a default, each when it sets none (docs/src/plugins.md).
  readonly property var itemDefaults: ({ icon: "", detail: "", active: false, enabled: true, done: false, hidden: false, busy: false, swatch: "", tone: "", verb: "", closes: false })

  // What a list holds, built-in or a plugin's, as the menu and the picker show it: each item's id is what pins match, `select` what its digit runs, `actions` its own menu.
  function items(list) {
    if (!list) return [];
    if (builtin[list]) return builtin[list].items();
    const plugin = Plugins.get(list);
    return Array.from(plugin?.items ?? []).map(item => Object.keys(itemDefaults).reduce((found, key) => Object.assign(found, { [key]: item[key] ?? itemDefaults[key] }), {
      id: item.id,
      desc: item.label ?? item.id,
      meter: item.meter,
      glyphs: Array.from(item.glyphs ?? []),
      select: () => plugin.select(item.id),
      actions: Array.from(item.actions ?? []).map(action => ({
        key: action.key, desc: action.desc ?? action.key, icon: action.icon ?? "", closes: action.closes ?? false, select: () => plugin.run(item.id, action.key)
      }))
    }));
  }

  function empty(list) {
    return builtin[list]?.empty() ?? Plugins.get(list)?.empty ?? "";
  }

  // Each device with its own volume and meter, which the wheel over it changes.
  function audio(devices, current) {
    return devices.map(device => {
      return {
        id: device.name,
        desc: device.label,
        icon: Glyphs.audioDevice(device.type),
        active: device.name === current,
        detail: Audio.level(device.node),
        meter: Audio.meter(device.node),
        adjust: up => Audio.adjust(device.node, up),
        select: () => Audio.select(device)
      };
    });
  }

  // An app's stream, by its name and icon (else the volume's glyph), as a device is.
  function stream(node, picked) {
    return {
      id: String(node.id),
      desc: node.properties["application.name"],
      image: Quickshell.iconPath(node.properties["application.icon-name"] ?? "", true),
      icon: Glyphs.volume,
      active: node === picked,
      detail: Audio.level(node),
      meter: Audio.meter(node),
      adjust: up => Audio.adjust(node, up),
      select: () => Audio.pick(node)
    };
  }

  // A device or network: connects it, or disconnects it when connected.
  function toggle(target) {
    if (target.connected) target.disconnect();
    else target.connect();
  }
}
