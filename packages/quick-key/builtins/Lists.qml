pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// The built-in lists by name; `list` names one of these or a plugin.
Singleton {
  id: root

  // Each: items() as { id, desc, select, closes, ... }, the icon a pin shows while absent, why it is empty, extra keys.
  readonly property var builtin: ({
    tray: {
      icon: Glyphs.tray,
      empty: () => "No apps in the tray",
      legend: [{ key: "Ctrl+digit", what: "app menu" }],
      items: () => Tray.items.map(app => ({ id: app.id, desc: app.title || app.id, image: app.icon, app, closes: true, select: () => app.activate() }))
    },
    wifi: {
      icon: Glyphs.wifi,
      empty: () => Network.wifiEnabled ? "No saved networks in range" : "",
      items: () => Network.known.map(network => ({ id: network.name, desc: network.name, icon: Glyphs.wifi, active: network.connected, select: () => root.toggle(network) }))
    },
    bluetooth: {
      icon: Glyphs.bluetooth,
      empty: () => !Bluez.present ? "No Bluetooth adapter" : Bluez.enabled ? "No paired devices" : "",
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

  function audio(devices, current) {
    return devices.map(device => ({
      id: device.name,
      desc: device.label,
      icon: Glyphs.audioDevice(device.type),
      active: device.name === current,
      select: () => Audio.select(device)
    }));
  }

  // A device or network: connects it, or disconnects it when connected.
  function toggle(target) {
    if (target.connected) target.disconnect();
    else target.connect();
  }
}
