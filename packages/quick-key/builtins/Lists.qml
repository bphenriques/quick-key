pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// The built-in lists by name; `list` names one of these or a plugin.
Singleton {
  id: root

  // Each: items() as { id, desc, select, closes, detail, meter, ... }, the icon a pin shows while absent, why it is empty, extra keys.
  readonly property var builtin: ({
    tray: {
      icon: Glyphs.tray,
      empty: () => "No apps in the tray",
      legend: [{ key: "Alt+digit", what: Words.appMenu }],
      items: () => Tray.items.map(app => ({ id: app.id, desc: app.title || app.id, image: app.icon, app, closes: true, select: () => app.activate() }))
    },
    wifi: {
      icon: Glyphs.wifi,
      empty: () => Network.wifiEnabled ? "No saved networks in range" : "Wi-Fi is off",
      items: () => Network.known.map(network => ({ id: network.name, desc: network.name, icon: Glyphs.wifi, active: network.connected, select: () => root.toggle(network) }))
    },
    bluetooth: {
      icon: Glyphs.bluetooth,
      empty: () => !Bluez.present ? "No Bluetooth adapter" : Bluez.enabled ? "No paired devices" : "Bluetooth is off",
      items: () => !Bluez.enabled ? [] : Bluez.paired.map(device => ({
        id: device.address,
        desc: device.name,
        icon: Glyphs.bluetooth,
        active: device.connected,
        detail: device.connected && device.batteryAvailable ? Math.round(device.battery * 100) + "%" : "",
        select: () => root.toggle(device)
      })).sort((a, b) => a.desc.localeCompare(b.desc))
    },
    sinks: {
      icon: Glyphs.audioDevice("external"),
      empty: () => "No outputs",
      items: () => root.audio(Audio.sinks, Audio.sink?.name)
    },
    sources: {
      icon: Glyphs.microphone,
      empty: () => "No inputs",
      items: () => root.audio(Audio.sources, Audio.source?.name)
    }
  })

  // Each device with its own volume and meter.
  function audio(devices, current) {
    return devices.map(device => {
      const audio = device.node.audio;
      return {
        id: device.name,
        desc: device.label,
        icon: Glyphs.audioDevice(device.type),
        active: device.name === current,
        detail: audio?.muted ? "muted" : Math.round((audio?.volume ?? 0) * 100) + "%",
        meter: audio?.volume ?? 0,
        select: () => Audio.select(device)
      };
    });
  }

  // A device or network: connects it, or disconnects it when connected.
  function toggle(target) {
    if (target.connected) target.disconnect();
    else target.connect();
  }
}
