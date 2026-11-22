pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// A notification server: Quickshell speaks the protocol; this decides what shows and for how long, and Cards.qml draws it.
Plugin {
  id: root

  views: ["Cards.qml"]

  // Kept over a reload, as keep awake is.
  readonly property bool paused: Kept.values[name + ".paused"] ?? false
  // A focused fullscreen window holds them as pause does: under it they would expire unseen.
  readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false
  // The cards have the keys (s-n), one surface at a time with the menu and panels.
  readonly property bool summoned: Panels.top === root
  // Critical ones first, then the newest; a replaced one keeps its place. Summoned, the order holds, so digits do, one that comes meanwhile going last.
  readonly property var ordered: internal.list.slice().sort(summoned ? (a, b) => internal.rank(a) - internal.rank(b) : (a, b) => critical(b) - critical(a) || b.id - a.id)
  // Summoned, every one shows, those held too, as many as there are digits.
  readonly property var showable: summoned ? ordered : ordered.filter(notification => critical(notification) || !paused && !fullscreen)
  readonly property var shown: showable.slice(0, summoned ? 9 : settings.limit)
  // Those over the limit, and those pause or a fullscreen window holds.
  readonly property int more: showable.length - shown.length
  readonly property int held: ordered.length - showable.length
  // The card the keys act on while summoned.
  readonly property var picked: internal.picked

  glyph: paused ? Glyphs.notificationsPaused : Glyphs.notifications
  text: ordered.length > 0 ? String(ordered.length) : ""
  active: paused
  error: internal.error
  words: ({
      taken: "Another notification daemon has the bus: stop it, then restart quick-key",
      open: "open",
      clear: "clear all",
      pause: "pause",
      resume: "resume",
      none: "Nothing new"
    })
  actions: ({
      summon: { icon: () => Glyphs.notifications, available: () => true, run: () => root.summon() },
      pause: { icon: () => root.glyph, state: root.name, available: () => true, run: () => root.togglePause() },
      clear: { icon: () => Glyphs.close, available: () => internal.list.length > 0, run: () => root.clear() },
      dismiss: { icon: () => Glyphs.close, available: () => root.newest() !== null, run: () => root.newest().dismiss() },
      invoke: { icon: () => Glyphs.notifications, available: () => root.newest() !== null, run: () => root.open(root.newest()) }
    })

  function critical(notification) {
    return notification.urgency === NotificationUrgency.Critical;
  }

  function togglePause() {
    Kept.set(name + ".paused", !paused);
  }

  // A click on its bell, or an entry showing it, gives the cards the keys.
  function activate() {
    summon();
  }

  function summon() {
    if (summoned) return;
    internal.frozen = ordered.map(notification => notification.id);
    Panels.open(root);
    internal.picked = newest();
  }

  function release() {
    if (summoned) Panels.back();
  }

  // The newest card on screen, which a binding acts on and summoning picks.
  function newest() {
    return shown.reduce((found, notification) => found === null || notification.id > found.id ? notification : found, null);
  }

  // Its default action, else dismissed: a click means done with it.
  function open(notification) {
    const action = Array.from(notification.actions).find(action => action.identifier === "default");
    if (action) action.invoke();
    else notification.dismiss();
  }

  function clear() {
    for (const notification of internal.list.slice()) notification.dismiss();
  }

  // The pointer is on its card: its timer holds.
  function hold(notification, on) {
    internal.held = on ? notification : internal.held === notification ? null : internal.held;
  }

  // Its sender's actions but the default, each with a letter from its label; `x`, which dismisses, is never one.
  function actionsOf(notification) {
    const actions = Array.from(notification?.actions ?? []).filter(action => action.identifier !== "default");
    const keys = MenuKeys.assign(actions.map(action => action.text), ["x"], "");
    return actions.map((action, i) => ({ desc: action.text, key: keys[i], run: () => action.invoke() }));
  }

  // A key while summoned: a digit picks a card, ↑↓ move the pick, its letters run its actions, RET opens it and lets go of the keys, x dismisses it; C-x clears all, C-p pauses, ESC lets go.
  function key(name) {
    const at = shown.indexOf(internal.picked);
    if (/^[1-9]$/.test(name) && shown[Number(name) - 1]) internal.picked = shown[Number(name) - 1];
    else if ((name === "Up" || name === "Down") && shown.length > 0) internal.picked = shown[Math.max(0, Math.min(shown.length - 1, at + (name === "Down" ? 1 : -1)))];
    else if (name === "Return" && internal.picked) {
      open(internal.picked);
      release();
    } else if (name === "x" && internal.picked) internal.picked.dismiss();
    else if (name === "Ctrl+x") clear();
    else if (name === "Ctrl+p") togglePause();
    else if (name === "Escape") release();
    else {
      const action = actionsOf(internal.picked).find(action => action.key && action.key === name);
      if (!action) return false;
      action.run();
    }
    return true;
  }

  function press(path) {
    summon();
    return path.trim().split(/\s+/).every(name => key(name));
  }

  function refresh() {
    check();
  }

  function check() {
    if (!settings.owner) return;
    call(settings.owner, [], (code, output) => internal.error = code === 0 && Number(output.trim().split(/\s+/).pop()) === Quickshell.processId ? "" : words.taken);
  }

  // What the rules that match it set, in order, later ones winning.
  function ruled(notification) {
    const fields = {
      app: notification.appName,
      summary: notification.summary,
      body: notification.body,
      category: String(notification.hints.category ?? ""),
      urgency: ["low", "normal", "critical"][notification.urgency],
      desktopEntry: notification.desktopEntry
    };
    return Array.from(settings.rules).filter(rule => Object.entries(rule.match ?? {}).every(([field, pattern]) => new RegExp(pattern).test(fields[field] ?? "")))
      .reduce((applied, rule) => Object.assign(applied, rule), {});
  }

  // Milliseconds it shows: its sender's, which Quickshell passes as the protocol does, in milliseconds; else its urgency's; 0 for never.
  function timeoutOf(notification) {
    if (critical(notification) || notification.expireTimeout === 0) return 0;
    if (notification.expireTimeout > 0) return notification.expireTimeout;
    return 1000 * (notification.urgency === NotificationUrgency.Low ? settings.timeout.low : settings.timeout.normal);
  }

  // Volume and brightness tools replace their last one by a tag.
  function tagOf(notification) {
    return String(notification.hints["x-dunst-stack-tag"] ?? notification.hints["x-canonical-private-synchronous"] ?? "");
  }

  // A hidden one is left untracked, so Quickshell drops it; a replaced one, by id or tag, starts its time again.
  function arrive(notification) {
    if (ruled(notification).hide) return;
    notification.tracked = true;
    const tag = tagOf(notification);
    for (const old of internal.list) {
      if (tag && old !== notification && old.appName === notification.appName && tagOf(old) === tag) old.expire();
    }
    internal.left = Object.assign({}, internal.left, { [notification.id]: timeoutOf(notification) });
    if (internal.list.includes(notification)) return;
    internal.list = internal.list.concat([notification]);
    notification.closed.connect(() => root.leave(notification));
  }

  // The pick moves to the card that takes its place; the last one gone lets go of the keys.
  function leave(notification) {
    const at = shown.indexOf(notification);
    internal.list = internal.list.filter(each => each !== notification);
    const left = Object.assign({}, internal.left);
    delete left[notification.id];
    internal.left = left;
    if (internal.held === notification) internal.held = null;
    if (internal.picked !== notification) return;
    internal.picked = shown[Math.min(at, shown.length - 1)] ?? null;
    if (internal.picked === null) release();
  }

  Component.onCompleted: check()

  QtObject {
    id: internal

    property var list: []
    // Milliseconds left by id, counted only while shown, not held and not summoned; 0 never expires.
    property var left: ({})
    property var held: null
    property var picked: null
    // The order as it was summoned, by id.
    property var frozen: []
    property string error: ""

    function rank(notification) {
      const at = frozen.indexOf(notification.id);
      return at < 0 ? frozen.length + notification.id : at;
    }
  }

  NotificationServer {
    keepOnReload: true
    actionsSupported: true
    imageSupported: true
    bodySupported: true
    bodyMarkupSupported: false
    bodyHyperlinksSupported: false
    onNotification: notification => root.arrive(notification)
  }

  Timer {
    interval: 200
    repeat: true
    running: !root.summoned && root.shown.some(notification => internal.left[notification.id] > 0 && notification !== internal.held)
    onTriggered: {
      const left = Object.assign({}, internal.left);
      const due = root.shown.filter(notification => notification !== internal.held && left[notification.id] > 0 && (left[notification.id] -= interval) <= 0);
      internal.left = left;
      for (const notification of due) notification.expire();
    }
  }
}
