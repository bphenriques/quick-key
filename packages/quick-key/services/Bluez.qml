pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Bluetooth
import qs

// Named after the BlueZ daemon so it does not shadow Quickshell's Bluetooth singleton.
Singleton {
  readonly property bool present: Bluetooth.defaultAdapter !== null
  readonly property bool enabled: Bluetooth.defaultAdapter?.enabled ?? false
  // Turned off with rfkill, which BlueZ cannot power on through.
  readonly property bool blocked: Bluetooth.defaultAdapter?.state === BluetoothAdapterState.Blocked
  readonly property var paired: Array.from(Bluetooth.defaultAdapter?.devices.values ?? []).filter(device => device.paired)
  readonly property var connected: paired.filter(device => device.connected)

  // Powers the adapter off, or on; a blocked one is unblocked (Config.bluetooth.unblock), and BlueZ powers it on.
  function toggle() {
    if (blocked) Commands.run(Config.bluetooth.unblock);
    else if (Bluetooth.defaultAdapter) Bluetooth.defaultAdapter.enabled = !enabled;
  }
}
