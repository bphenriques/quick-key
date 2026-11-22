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
  // Summoned or under the pointer, nothing moves and no time runs: the order holds, one that comes meanwhile going last.
  readonly property bool still: summoned || internal.hovered
  readonly property var ordered: internal.list.slice().sort(still ? (a, b) => internal.rank(a) - internal.rank(b) : (a, b) => critical(b) - critical(a) || b.id - a.id)
  // Summoned, the held ones show too.
  readonly property var showable: summoned ? ordered : ordered.filter(notification => critical(notification) || !fullscreen && (!paused || !!internal.applied[notification.id]?.ignorePause))
  // `limit` at a time; summoned, the arrows scroll past them, digits following what shows.
  readonly property var shown: showable.slice(internal.offset, internal.offset + settings.limit)
  readonly property int first: internal.offset
  // Those not shown, and those pause or a fullscreen window holds.
  readonly property int more: showable.length - shown.length
  readonly property int held: ordered.length - showable.length
  // The card the keys act on while summoned.
  readonly property var picked: internal.picked
  // The card being replied to, its prompt in its actions' place; and what was sent, by id, shown until it goes.
  readonly property var replying: internal.replying
  readonly property var sent: internal.sent

  glyph: paused ? Glyphs.notificationsPaused : Glyphs.notifications
  text: ordered.length > 0 ? String(ordered.length) : ""
  active: paused
  error: internal.error
  words: ({
      taken: "Another notification daemon has the bus: stop it, then restart quick-key",
      clear: "clear all",
      pause: "pause",
      resume: "resume",
      none: "No notifications",
      send: "send",
      sendClose: "send and close",
      closed: "closed"
    })
  actions: ({
      summon: { icon: () => Glyphs.notifications, available: () => true, run: () => root.summon() },
      pause: { icon: () => root.glyph, state: root.name, available: () => true, run: () => root.togglePause() },
      clear: { icon: () => Glyphs.close, available: () => internal.list.length > 0, run: () => root.clear() },
      dismiss: { icon: () => Glyphs.close, available: () => root.newest() !== null, run: () => root.newest().dismiss() },
      invoke: { icon: () => Glyphs.notifications, available: () => root.newest() !== null, run: () => root.open(root.newest()) }
    })

  function critical(notification) {
    return urgencyOf(notification) === "critical";
  }

  // Its sender's, unless a rule sets another.
  function urgencyOf(notification) {
    return internal.applied[notification.id]?.urgency ?? ["low", "normal", "critical"][notification.urgency];
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
    freeze();
    internal.offset = 0;
    Panels.open(root);
    internal.picked = newest();
  }

  function release() {
    endReply();
    internal.offset = 0;
    if (summoned) Panels.back();
  }

  // The order as it is now, which `still` keeps.
  function freeze() {
    if (!still) internal.frozen = ordered.map(notification => notification.id);
  }

  // The newest card on screen, which a binding acts on and summoning picks.
  function newest() {
    return shown.reduce((found, notification) => found === null || notification.id > found.id ? notification : found, null);
  }

  // A rule's `default`, else its own default action, else dismissed: a click means done with it.
  function open(notification) {
    const rule = internal.applied[notification.id]?.default;
    if (rule) {
      runFor(notification, rule);
      return notification.dismiss();
    }
    const action = Array.from(notification.actions).find(action => action.identifier === "default");
    if (action) action.invoke();
    else notification.dismiss();
  }

  function clear() {
    for (const notification of internal.list.slice()) notification.dismiss();
  }

  // The pointer is on a card: every one holds still, so the one under it stays there.
  function hold(on) {
    if (on) freeze();
    internal.hovered = on;
  }

  // Its reply first, on TAB, then its rules' actions on their keys, then its sender's but the default, each with a letter its label offers, else any, that neither those nor `x`, which dismisses, take; none once a reply shows in their place.
  function actionsOf(notification) {
    if (!notification || notification.gone || notification.id in internal.sent) return [];
    const values = valuesOf(notification);
    const ruled = Array.from(internal.applied[notification.id]?.actions ?? []).map(action => ({ desc: action.desc.replace(/\{(\w+)\}/g, (all, name) => values[name] ?? all), key: action.key, run: () => {
        root.runFor(notification, action.cmd);
        if (action.closes === false) return;
        notification.dismiss();
        root.release();
      } }));
    const actions = Array.from(notification.actions).filter(action => action.identifier !== "default");
    const keys = MenuKeys.assign(actions.map(action => action.text), ["x"].concat(ruled.map(action => action.key)), "abcdefghijklmnopqrstuvwyz");
    const own = actions.map((action, i) => ({ desc: action.text, key: keys[i], run: () => action.invoke() }));
    const reply = notification.hasInlineReply ? [{ desc: Words.replyPrompt, key: "Tab", run: () => root.reply(notification) }] : [];
    return reply.concat(ruled, own);
  }

  // Its prompt in its actions' place, summoned and picked; a click on Reply... starts here too.
  function reply(notification) {
    summon();
    internal.picked = notification;
    internal.replying = notification;
  }

  // Back to the card's keys; a closed one's placeholder goes.
  function endReply() {
    const ended = internal.replying;
    internal.replying = null;
    if (ended?.gone) leave(ended);
  }

  // A card's unsent reply, kept while the keys move elsewhere, until it goes.
  function draftOf(notification) {
    return internal.drafts[notification?.id] ?? "";
  }

  function keepDraft(notification, text) {
    if (notification) internal.drafts = Object.assign({}, internal.drafts, { [notification.id]: text });
  }

  // Sent as the reply; false once its card is closed, the prompt keeping the text. The keys stay only on a card its sender keeps (resident), which shows what was sent; else, as with C-S-RET, they go back.
  function sendReply(text, close) {
    const notification = internal.replying;
    if (!notification || notification.gone) return false;
    internal.sent = Object.assign({}, internal.sent, { [notification.id]: text });
    internal.drafts = without(internal.drafts, notification.id);
    notification.sendInlineReply(text);
    if (close || !notification.resident) release();
    else endReply();
    return true;
  }

  // The reply to a card that closed meanwhile, to the clipboard, never lost.
  function copyReply(text) {
    Quickshell.clipboardText = text;
    internal.drafts = without(internal.drafts, internal.replying?.id);
    endReply();
  }

  // ↑↓ as they show: newest by the corner, so at a bottom one Down goes toward it; past the last shown they scroll.
  function move(down) {
    const by = down === settings.corner.startsWith("top") ? 1 : -1;
    const next = shown.indexOf(internal.picked) + by;
    if (next >= 0 && next < shown.length) internal.picked = shown[next];
    else if (next >= shown.length && internal.offset + shown.length < showable.length) {
      internal.offset++;
      internal.picked = shown[shown.length - 1];
    } else if (next < 0 && internal.offset > 0) {
      internal.offset--;
      internal.picked = shown[0];
    }
  }

  // A key while summoned: a digit picks a card, ↑↓ move the pick, its letters run its actions, RET opens it and lets go of the keys, x dismisses it; C-X clears all, C-p pauses, ESC lets go.
  function key(name) {
    if (/^[1-9]$/.test(name) && shown[Number(name) - 1]) internal.picked = shown[Number(name) - 1];
    else if (name === "Up" || name === "Down") move(name === "Down");
    else if (name === "Return" && internal.picked) {
      open(internal.picked);
      release();
    } else if (name === "x" && internal.picked) internal.picked.dismiss();
    else if (name === "Ctrl+X") clear();
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

  // What the rules that match it set, in order, later ones winning but actions adding up; `values` the text its named groups found.
  function ruled(notification) {
    const fields = {
      app: notification.appName,
      summary: notification.summary,
      body: notification.body,
      category: String(notification.hints.category ?? ""),
      urgency: ["low", "normal", "critical"][notification.urgency],
      desktopEntry: notification.desktopEntry
    };
    const applied = { actions: [], values: {} };
    for (const rule of Array.from(settings.rules)) {
      const values = {};
      const matched = Object.entries(rule.match ?? {}).every(([field, pattern]) => {
        const found = new RegExp(pattern).exec(fields[field] ?? "");
        settings.groupNames(pattern).forEach((name, i) => {
          if (found && name) values[name] = found[i + 1] ?? "";
        });
        return found !== null;
      });
      if (matched) Object.assign(applied, rule, { actions: applied.actions.concat(Array.from(rule.actions ?? [])), values: Object.assign(applied.values, values) });
    }
    return applied;
  }

  // What a rule's labels and commands read: its app, summary, body, urgency and id, its picture or icon as a file (`icon`, as niri sends a screenshot), and what its groups found.
  function valuesOf(notification) {
    return Object.assign({ app: notification.appName, summary: notification.summary, body: notification.body, urgency: urgencyOf(notification), id: String(notification.id), icon: fileOf(notification) || iconOf(notification) }, internal.applied[notification.id]?.values);
  }

  // Its icon as sent: a file or a name, from its image-path hint (notify-send -i), else its app icon (niri's screenshot).
  function iconOf(notification) {
    return String(notification.hints["image-path"] ?? "") || notification.appIcon || "";
  }

  // Its icon as a path when it is a file, else "".
  function fileOf(notification) {
    const icon = iconOf(notification);
    return icon.startsWith("file://") ? decodeURIComponent(icon.slice(7)) : icon.startsWith("/") ? icon : "";
  }

  // A rule's command, given them in its environment as NOTIFICATION_<NAME>, as dunst gives DUNST_*.
  function runFor(notification, cmd) {
    const environment = {};
    for (const [name, value] of Object.entries(valuesOf(notification))) environment["NOTIFICATION_" + name.toUpperCase()] = value;
    Commands.runWith(cmd, environment);
  }

  // Milliseconds it shows: a rule's, else its sender's, which Quickshell passes as the protocol does, in milliseconds; else its urgency's; 0 for never, as for a critical one.
  function timeoutOf(notification) {
    const rule = internal.applied[notification.id]?.timeout;
    if (critical(notification)) return 0;
    if (rule !== undefined) return rule * 1000;
    if (notification.expireTimeout >= 0) return notification.expireTimeout;
    return 1000 * (urgencyOf(notification) === "low" ? settings.timeout.low : settings.timeout.normal);
  }

  // Volume and brightness tools replace their last one by a tag.
  function tagOf(notification) {
    return String(notification.hints["x-dunst-stack-tag"] ?? notification.hints["x-canonical-private-synchronous"] ?? "");
  }

  // A hidden one is left untracked, so Quickshell drops it; a replaced one, by id or tag, starts its time again, and `run` runs for a new one only.
  function arrive(notification) {
    const applied = ruled(notification);
    if (applied.hide) return;
    const known = internal.list.includes(notification);
    internal.applied = Object.assign({}, internal.applied, { [notification.id]: applied });
    if (applied.run && !known) runFor(notification, applied.run);
    notification.tracked = true;
    const tag = tagOf(notification);
    for (const old of internal.list) {
      if (tag && old !== notification && old.appName === notification.appName && tagOf(old) === tag) old.expire();
    }
    internal.left = Object.assign({}, internal.left, { [notification.id]: timeoutOf(notification) });
    if (known) return;
    internal.list = internal.list.concat([notification]);
    notification.closed.connect(() => root.leave(notification));
  }

  // The pick moves to the card that takes its place; the last one gone lets go of the keys. One closing while replied to stays as a placeholder, its slot and the text kept, until the reply ends.
  function leave(notification) {
    if (notification === internal.replying && !notification.gone) {
      const ghost = { id: notification.id, summary: notification.summary, body: notification.body, appName: notification.appName, appIcon: notification.appIcon, image: notification.image, urgency: notification.urgency, hints: ({}), actions: [], gone: true, dismiss: () => root.endReply() };
      internal.list = internal.list.map(each => each === notification ? ghost : each);
      internal.replying = internal.picked = ghost;
      return;
    }
    const at = shown.indexOf(notification);
    internal.list = internal.list.filter(each => each !== notification);
    internal.left = without(internal.left, notification.id);
    internal.sent = without(internal.sent, notification.id);
    internal.applied = without(internal.applied, notification.id);
    internal.drafts = without(internal.drafts, notification.id);
    if (internal.offset > 0 && internal.offset + settings.limit > showable.length) internal.offset--;
    if (internal.picked !== notification) return;
    internal.picked = shown[Math.min(at, shown.length - 1)] ?? null;
    if (internal.picked === null) release();
  }

  function without(map, id) {
    const rest = Object.assign({}, map);
    delete rest[id];
    return rest;
  }

  Component.onCompleted: check()

  QtObject {
    id: internal

    property var list: []
    // Milliseconds left by id, counted only while shown and nothing holds them; 0 never expires.
    property var left: ({})
    property bool hovered: false
    property var picked: null
    property var replying: null
    property var sent: ({})
    property var drafts: ({})
    // What the rules matching it set, by id.
    property var applied: ({})
    // The order as it was when it held still, by id.
    property var frozen: []
    // The first shown, summoned, past those scrolled by.
    property int offset: 0
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
    inlineReplySupported: true
    onNotification: notification => root.arrive(notification)
  }

  // Away from the keyboard, no time runs: with no history, one shown meanwhile would be gone unseen.
  IdleMonitor {
    id: idle
    enabled: root.settings.idle > 0
    timeout: root.settings.idle
  }

  Timer {
    interval: 200
    repeat: true
    running: !root.still && !idle.isIdle && root.shown.some(notification => internal.left[notification.id] > 0)
    onTriggered: {
      const left = Object.assign({}, internal.left);
      const due = root.shown.filter(notification => left[notification.id] > 0 && (left[notification.id] -= interval) <= 0);
      internal.left = left;
      for (const notification of due) notification.expire();
    }
  }
}
