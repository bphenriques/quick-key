pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Services.UPower
import qs
import qs.ui

// Plugged in is read from the battery's own state, the same source as its percentage, not UPower's separate onBattery flag.
Singleton {
  // Nothing until UPower has answered: before that the percentage reads 0, which would show as critical.
  readonly property bool present: UPower.displayDevice.ready && UPower.displayDevice.isLaptopBattery
  readonly property int percentage: Math.round(UPower.displayDevice.percentage * 100)
  readonly property bool pluggedIn: [UPowerDeviceState.Charging, UPowerDeviceState.FullyCharged, UPowerDeviceState.PendingCharge].includes(UPower.displayDevice.state)
  // Warning levels apply only on battery, at Config.battery's thresholds.
  readonly property string level: !present || pluggedIn ? "normal"
    : percentage <= Config.battery.critical ? "critical"
    : percentage <= Config.battery.low ? "low"
    : "normal"

  // A warning as the charge falls to low or critical on battery (Config.battery.warn), once each and never for the state at start: what it was told last.
  onLevelChanged: {
    const warning = warns(internal.level, level);
    internal.level = level;
    if (warning && internal.settled) Commands.run(Config.battery.warn, warning === "critical" ? Words.batteryCritical : Words.batteryLow, Words.batteryLeft(percentage));
  }

  // The warning a change of level calls for: a worse one, never a better one (charging, or plugged in).
  function warns(from, to) {
    const rank = { normal: 0, low: 1, critical: 2 };
    return rank[to] > (rank[from] ?? 0) ? to : "";
  }

  // Power profiles, only where their daemon is (power-profiles-daemon, tuned-ppd): without it Quickshell still reads one, balanced, that nothing applies.
  readonly property bool profilesPresent: Daemons.has("org.freedesktop.UPower.PowerProfiles")
  // Those to pick, performance where the machine has it, and the one in use; none without the daemon.
  readonly property var profiles: profilesPresent ? internal.names.slice(0, PowerProfiles.hasPerformanceProfile ? 3 : 2) : []
  readonly property string profile: profilesPresent ? internal.names[internal.ids.indexOf(PowerProfiles.profile)] ?? "" : ""

  function setProfile(name) {
    if (profiles.includes(name)) PowerProfiles.profile = internal.ids[internal.names.indexOf(name)];
  }

  function nextProfile() {
    setProfile(profiles[(profiles.indexOf(profile) + 1) % profiles.length]);
  }

  Connections {
    target: UPower.displayDevice

    function onReadyChanged() {
      if (UPower.displayDevice.ready) Qt.callLater(() => internal.settled = true);
    }
  }

  Component.onCompleted: if (UPower.displayDevice.ready) Qt.callLater(() => internal.settled = true)

  QtObject {
    id: internal
    readonly property var ids: [PowerProfile.PowerSaver, PowerProfile.Balanced, PowerProfile.Performance]
    readonly property var names: ["power-saver", "balanced", "performance"]
    property string level: "normal"
    // UPower has reported: the level it first gives is the state at start, not a fall.
    property bool settled: false
  }
}
