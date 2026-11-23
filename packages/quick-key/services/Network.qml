pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Networking

// The connection in use, and the Wi-Fi radio with its saved networks in range.
Singleton {
  id: root

  readonly property string kind: internal.device === null ? "none" : internal.device.type === DeviceType.Wired ? "wired" : "wifi"
  readonly property string ssid: kind === "wifi" ? (internal.network?.name ?? internal.device.name) : ""
  // The Wi-Fi signal in use, 0 to 100.
  readonly property int strength: kind === "wifi" ? Math.round((internal.network?.signalStrength ?? 0) * 100) : 0
  // Behind a captive portal, or short of the internet, as NetworkManager's connectivity check finds.
  readonly property bool limited: Networking.connectivity === NetworkConnectivity.Portal || Networking.connectivity === NetworkConnectivity.Limited
  readonly property bool wifiPresent: internal.wifi !== null
  readonly property bool wifiEnabled: Networking.wifiEnabled
  // Off at the hardware switch, which no software can turn on.
  readonly property bool wifiBlocked: !Networking.wifiHardwareEnabled
  // Saved networks in range, by name so their keys hold still as the signal changes.
  readonly property var known: wifiEnabled && internal.wifi ? Array.from(internal.wifi.networks.values).filter(network => network.known).sort((a, b) => a.name.localeCompare(b.name)) : []

  function toggleWifi() {
    Networking.wifiEnabled = !Networking.wifiEnabled;
  }

  // Scans for networks in range while on.
  function scan(on) {
    if (internal.wifi) internal.wifi.scannerEnabled = on;
  }

  QtObject {
    id: internal
    readonly property var device: Networking.devices.values.find(device => device.connected && device.type !== DeviceType.None) ?? null
    readonly property var network: root.kind === "wifi" ? device.networks.values.find(network => network.connected) ?? null : null
    readonly property var wifi: Networking.devices.values.find(device => device.type === DeviceType.Wifi) ?? null
  }
}
