pragma Singleton

import QtQuick
import Quickshell

// The words the surfaces share, one per meaning, so a state or a key is never named two ways (AGENTS.md rules 6 and 7).
Singleton {
  // The one ellipsis: what opens a picker or an app, what is under way, what waits on you.
  readonly property string ellipsis: "..."

  // A conversation's phases, as its answer and the prompt under it say them.
  readonly property string replyPrompt: "Reply" + ellipsis
  readonly property string approvePrompt: MenuKeys.label("Ctrl+y") + " allows, " + MenuKeys.label("Ctrl+n") + " denies, " + MenuKeys.label("Ctrl+c") + " stops" + ellipsis
  readonly property string syncing: "syncing" + ellipsis
  // A picker's filter, empty and when it leaves nothing.
  readonly property string filterPrompt: "Filter" + ellipsis

  // What Return does after a turn in `phase`, for the prompt under it: nothing while it works, where the answer says so and typing ahead is free.
  function next(phase, kind) {
    return phase === "working" ? "" : kind === "permission" ? approvePrompt : replyPrompt;
  }

  // A list's rows at rest of all it holds, when it holds more (1-9 of 14).
  function shownOf(total) {
    return "1-9 of " + total;
  }

  // Rows shown of all there are, from the first shown (2-10 of 14).
  function rangeOf(first, count, total) {
    return (count > 1 ? (first + 1) + "-" + (first + count) : String(first + 1)) + " of " + total;
  }

  function noMatch(text) {
    return "Nothing matches " + text;
  }

  function updated(when) {
    return "updated " + when;
  }

  // When an event runs: all day, from one time to another, or to when it ends.
  readonly property string allDay: "All day"
  function range(from, to) {
    return from + "–" + to;
  }
  function until(when) {
    return "to " + when;
  }

  // Today's events that are over, folded into one line.
  function earlier(count) {
    return count + " earlier";
  }

  // What a line says beside another (09:00–09:15 · Rua Augusta 120), the empty left out.
  function beside(parts) {
    return parts.filter(part => part).join(" · ");
  }

  // Why an empty list says it is empty.
  readonly property string emptyTray: "No apps in the tray"
  readonly property string emptyNetworks: "No saved networks in range"
  readonly property string emptyWifiOff: "Wi-Fi is off"
  readonly property string emptyNoAdapter: "No Bluetooth adapter"
  readonly property string emptyNoPaired: "No paired devices"
  readonly property string emptyBluetoothOff: "Bluetooth is off"
  readonly property string emptyOutputs: "No outputs"
  readonly property string emptyInputs: "No inputs"
  readonly property string emptyStreams: "No app playing sound"
  readonly property string noSong: "No song playing"
  readonly property string noDevice: "No device connected"
  readonly property string noEvents: "No events"
  // A day past the range the events file was synced over.
  readonly property string notSynced: "Not synced"
  readonly property string noPowerProfiles: "No power profiles"
  // A battery warning: its title, and how much is left.
  readonly property string batteryLow: "Battery low"
  readonly property string batteryCritical: "Battery critical"
  function batteryLeft(percentage) {
    return percentage + "% left";
  }
  // A power profile by its name, as a row says it; lowercase on a row's right.
  readonly property var powerProfiles: ({ "power-saver": "Power saver", balanced: "Balanced", performance: "Performance" })

  function devicesConnected(count) {
    return count + " devices connected";
  }

  // A value's words, on the right of a row.
  readonly property string off: "off"
  readonly property string paused: "paused"
  readonly property string wifiOff: "Wi-Fi off"
  readonly property string disconnected: "Disconnected"
  readonly property string ethernet: "Ethernet"
  readonly property string noInternet: "No internet"
  readonly property string muted: "muted"

  // What carries the sound when its own name says nothing.
  readonly property string speakers: "Speakers"
  readonly property string headphones: "Headphones"

  // A named toggle's pill, the state in its name.
  function keepAwakeState(keep) {
    return "Keep awake " + (keep ? "on" : "off");
  }

  // What a key does, in a legend: a lowercase word or two.
  readonly property string appMenu: "app menu"
  readonly property string choose: "choose"
  readonly property string clear: "clear"
  readonly property string copy: "copy"
  readonly property string day: "day"
  readonly property string details: "details"
  readonly property string event: "event"
  readonly property string events: "events"
  readonly property string help: "keys"
  readonly property string history: "history"
  readonly property string menu: "menu"
  readonly property string month: "month"
  readonly property string move: "move"
  readonly property string open: "open"
  readonly property string pick: "pick"
  readonly property string today: "today"
  readonly property string week: "week"
  readonly property string year: "year"

  // What a key does, listed on `?`.
  readonly property string helpBarKeys: "Hold: the bar's keys"
  readonly property string helpCompositor: "Hold: compositor shortcuts"
  readonly property string helpItemMenu: "Open an item's own menu"
  readonly property string helpFilter: "Filter the list"
  readonly property string helpTab: "Go to the input and back"
  readonly property string helpBackground: "Send in the background"
  readonly property string helpRecall: "Resume an earlier conversation"
  readonly property string helpEscape: "Clear, else back"
}
