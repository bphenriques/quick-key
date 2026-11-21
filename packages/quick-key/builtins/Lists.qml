pragma Singleton

import QtQuick
import Quickshell
import qs.services
import qs.ui

// The built-in lists by name; `list` names one of these or a plugin; a table without a prototype, so no name every object inherits (toString) is one.
Singleton {
  id: root

  // Each: items() as { id, desc, select, closes, detail, meter, ... }, the icon a pin shows while absent, why it is empty, extra keys.
  readonly property var builtin: Object.assign(Object.create(null), {
    tray: {
      icon: Glyphs.tray,
      empty: () => Words.emptyTray,
      legend: [{ key: "Alt+digit", what: Words.appMenu }],
      items: () => Tray.items.map(app => ({ id: app.id, desc: app.title || app.id, image: app.icon, app, closes: true, select: () => app.activate() }))
    },
    wifi: {
      icon: Glyphs.wifi,
      empty: () => Network.wifiEnabled ? Words.emptyNetworks : Words.emptyWifiOff,
      items: () => Network.known.map(network => ({ id: network.name, desc: network.name, icon: Glyphs.wifi, active: network.connected, select: () => root.toggle(network) }))
    },
    bluetooth: {
      icon: Glyphs.bluetooth,
      empty: () => !Bluez.present ? Words.emptyNoAdapter : Bluez.enabled ? Words.emptyNoPaired : Words.emptyBluetoothOff,
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
      empty: () => Words.emptyOutputs,
      items: () => root.audio(Audio.sinks, Audio.sink?.name)
    },
    sources: {
      icon: Glyphs.microphone,
      empty: () => Words.emptyInputs,
      items: () => root.audio(Audio.sources, Audio.source?.name)
    }
  })

  // What a list holds, built-in or a plugin's, as the menu and the picker show it: each item's id is what pins match, `select` what its digit runs, `actions` its own menu.
  function items(list) {
    if (!list) return [];
    if (builtin[list]) return builtin[list].items();
    const plugin = Plugins.get(list);
    return Array.from(plugin?.items ?? []).map(item => ({
      id: item.id,
      desc: item.label ?? item.id,
      icon: item.icon ?? "",
      detail: item.detail ?? "",
      meter: item.meter,
      active: item.active ?? false,
      enabled: item.enabled ?? true,
      done: item.done ?? false,
      hidden: item.hidden ?? false,
      busy: item.busy ?? false,
      glyphs: Array.from(item.glyphs ?? []),
      tone: item.tone ?? "",
      verb: item.verb ?? "",
      closes: item.closes ?? false,
      select: () => plugin.select(item.id),
      actions: Array.from(item.actions ?? []).map(action => ({ key: action.key, desc: action.desc ?? action.key, icon: action.icon ?? "", closes: action.closes ?? false, select: () => plugin.run(item.id, action.key) }))
    }));
  }

  // Why a list is empty, in its own words.
  function empty(list) {
    return builtin[list]?.empty() ?? Plugins.get(list)?.empty ?? "";
  }

  // Each device with its own volume and meter.
  function audio(devices, current) {
    return devices.map(device => {
      const audio = device.node.audio;
      return {
        id: device.name,
        desc: device.label,
        icon: Glyphs.audioDevice(device.type),
        active: device.name === current,
        detail: Audio.level(device.node),
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
