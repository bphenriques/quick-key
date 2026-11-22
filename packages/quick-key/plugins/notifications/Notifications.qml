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
  // The cards have the keys (s-n), one surface at a time with the menu and panels.
  readonly property bool summoned: Panels.top === root
  // Summoned or under the pointer, nothing moves and no time runs: the order holds, one that comes meanwhile going last.
  readonly property bool still: summoned || internal.hovered
  readonly property var ordered: internal.list.slice().sort((a, b) => critical(b) - critical(a) || (still ? internal.rank(a) - internal.rank(b) : internal.came[b.id] - internal.came[a.id]))
  // Summoned, the held ones show too.
  readonly property var showable: summoned ? ordered : ordered.filter(notification => critical(notification) || !internal.fullscreen && (!paused || !!internal.applied[notification.id]?.ignorePause))
  // Critical ones by the corner, leaving a place while others wait, then the rest `limit` at a time, summoned the arrows scrolling past them; a card's digit is its place among all, so it holds still.
  readonly property var shown: showable.slice(0, internal.pinned).concat(internal.rest.slice(internal.offset, internal.offset + internal.room))
  // Those showable but not shown.
  readonly property int more: showable.length - shown.length
  // None under a fullscreen window: the count would sit over it.
  readonly property int held: internal.fullscreen ? 0 : ordered.length - showable.length
  // The keys, listed while `?` holds them, as the menu lists its own.
  readonly property bool help: internal.help
  readonly property var keys: [
    { key: "1-9", desc: words.helpPick },
    { key: ["Up", "Down"], desc: words.helpMove },
    { key: "Return", desc: words.helpOpen },
    { key: "x", desc: words.helpDismiss },
    { key: "Tab", desc: words.helpReply },
    { key: "Ctrl+Shift+Return", desc: words.helpLeave },
    { key: "Ctrl+Shift+x", desc: words.helpClear },
    { key: "Ctrl+r", desc: words.helpRestore },
    { key: "Ctrl+p", desc: words.helpPause },
    { key: "Escape", desc: Words.helpEscape }
  ]
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
      pause: "pause",
      resume: "resume",
      none: "No notifications",
      send: "send",
      copyReply: "copy reply",
      you: "You: ",
      closedBySender: "closed by sender",
      helpPick: "Pick that card",
      helpMove: "Move the pick, scrolling",
      helpOpen: "Open it and let go",
      helpLeave: "Send and let go",
      helpDismiss: "Dismiss it",
      helpReply: "Reply, where it takes one",
      helpClear: "Clear all",
      helpRestore: "Bring back the last closed",
      helpPause: "Pause or resume"
    })
  actions: ({
      summon: { icon: () => Glyphs.notifications, available: () => true, run: () => root.summon() },
      pause: { icon: () => root.glyph, state: root.name, available: () => true, run: () => root.togglePause() },
      clear: { icon: () => Glyphs.close, available: () => internal.list.length > 0, run: () => root.clear() },
      dismiss: { icon: () => Glyphs.close, available: () => root.newest() !== null, run: () => root.newest().dismiss() },
      invoke: { icon: () => Glyphs.notifications, available: () => root.newest() !== null, run: () => root.open(root.newest()) },
      restore: { icon: () => Glyphs.notifications, available: () => internal.closed.length > 0, run: () => root.restore() }
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
    Panels.open(root);
    internal.picked = newest();
  }

  function release() {
    if (summoned) Panels.back();
  }

  // However the keys go (ESC, the menu opening over the cards), the reply, the scroll and the list go with them.
  onSummonedChanged: {
    if (summoned) return;
    endReply();
    internal.offset = 0;
    internal.help = false;
  }

  // The order as it is now, which `still` keeps.
  function freeze() {
    if (!still) internal.frozen = ordered.map(notification => notification.id);
  }

  // The newest card on screen, which a binding acts on and summoning picks.
  function newest() {
    return shown.reduce((found, notification) => found === null || internal.came[notification.id] > internal.came[found.id] ? notification : found, null);
  }

  // A rule's `default`, else its own default action, else dismissed: a click means done with it.
  function open(notification) {
    if (notification.gone) return notification.dismiss();
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
    if (!notification || notification.gone || notification.restored || notification.id in internal.sent) return [];
    const values = valuesOf(notification);
    const ruled = Array.from(internal.applied[notification.id]?.actions ?? []).map(action => ({ desc: action.desc.replace(/\{(\w+)\}/g, (all, name) => values[name] ?? all), key: action.key, run: () => {
        root.runFor(notification, action.cmd);
        if (action.closes !== false) notification.dismiss();
      } }));
    const actions = Array.from(notification.actions).filter(action => action.identifier !== "default");
    const keys = MenuKeys.assign(actions.map(action => action.text), ["x"].concat(ruled.map(action => action.key)), "abcdefghijklmnopqrstuvwxyz");
    const own = actions.map((action, i) => ({ desc: action.text, key: keys[i], run: () => action.invoke() }));
    const reply = notification.hasInlineReply ? [{ desc: Words.replyPrompt, key: "Tab", run: () => root.reply(notification) }] : [];
    return reply.concat(ruled, own);
  }

  // Its prompt in its actions' place, summoned and picked; a click on Reply... starts here too.
  function reply(notification) {
    summon();
    pick(notification);
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

  // False once its card closed, the prompt keeping the text; the keys stay only on a resident card.
  function sendReply(text, close) {
    const notification = internal.replying;
    if (!notification || notification.gone) return false;
    internal.sent = Object.assign({}, internal.sent, { [notification.id]: text });
    internal.drafts = without(internal.drafts, notification.id);
    // No longer the reply target, so if the reply closes it, it is kept to bring back.
    internal.replying = null;
    notification.sendInlineReply(text);
    if (close || !notification.resident) release();
    return true;
  }

  // The reply to a card that closed meanwhile, to the clipboard, never lost.
  function copyReply(text) {
    Quickshell.clipboardText = text;
    internal.drafts = without(internal.drafts, internal.replying?.id);
    endReply();
  }

  // ↑↓ as they show: newest by the corner, so at a bottom one Down goes toward it; past the last shown, or back past the first of the rest, they scroll.
  function move(down) {
    const by = down === settings.corner.startsWith("top") ? 1 : -1;
    const at = shown.indexOf(internal.picked);
    if (by < 0 && at === internal.pinned && internal.offset > 0) {
      internal.offset--;
      internal.picked = shown[internal.pinned];
    } else if (by > 0 && at === shown.length - 1 && internal.offset + internal.room < internal.rest.length) {
      internal.offset++;
      internal.picked = shown[shown.length - 1];
    } else if (at + by >= 0 && at + by < shown.length) {
      internal.picked = shown[at + by];
    }
  }

  // A card by its digit, its place among all, scrolled into view.
  function pick(notification) {
    if (!notification) return false;
    const at = internal.rest.indexOf(notification);
    if (at >= 0 && at < internal.offset) internal.offset = at;
    else if (at >= internal.offset + internal.room) internal.offset = at - internal.room + 1;
    internal.picked = notification;
    return true;
  }

  // The last card that closed, back in the stack, only to read: its sender is done with it.
  function restore() {
    const last = internal.closed[internal.closed.length - 1];
    if (!last) return;
    internal.closed = internal.closed.slice(0, -1);
    const card = Object.assign({}, last, { restored: true });
    internal.came[card.id] = ++internal.seq;
    card.dismiss = card.expire = () => root.leave(card);
    internal.list = internal.list.concat([card]);
    internal.left = Object.assign({}, internal.left, { [card.id]: critical(card) ? 0 : 1000 * settings.timeout.normal });
    internal.arrived = Object.assign({}, internal.arrived, { [card.id]: last.arrived });
    if (summoned) pick(card);
  }

  // When it came, once it has waited a minute or more (held by pause, idle or a fullscreen window): so an old one never reads as new.
  function ageOf(notification) {
    const since = internal.arrived[notification.id];
    return since && Clock.date - since >= 60000 ? Clock.time(new Date(since)) : "";
  }

  function key(name) {
    // The prompt has the keys: what it leaves (arrows, chords) would act on the cards under the text; Escape, from a binding, still lets go.
    if (internal.replying && name !== "Escape") return false;
    if (internal.help) internal.help = false;
    else if (name === "?") internal.help = true;
    else if (/^[1-9]$/.test(name)) return pick(showable[Number(name) - 1]);
    else if (name === "Up" || name === "Down") move(name === "Down");
    else if (name === "Return" && internal.picked) {
      open(internal.picked);
      release();
    } else if (name === "x" && internal.picked) internal.picked.dismiss();
    else if (name === "Ctrl+X") clear();
    else if (name === "Ctrl+p") togglePause();
    else if (name === "Ctrl+r") restore();
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

  // What the rules that match it set, in order, later ones winning, actions adding up but one on a key taken before replacing it; `values` the text its named groups found.
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
      const actions = Array.from(rule.actions ?? []);
      if (matched) Object.assign(applied, rule, { actions: applied.actions.filter(action => !actions.some(other => other.key === action.key)).concat(actions), values: Object.assign(applied.values, values) });
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
    if (critical(notification)) return 0;
    const rule = internal.applied[notification.id]?.timeout;
    if (rule !== undefined) return rule * 1000;
    if (notification.expireTimeout >= 0) return notification.expireTimeout;
    return 1000 * (urgencyOf(notification) === "low" ? settings.timeout.low : settings.timeout.normal);
  }

  // Volume and brightness tools replace their last one by a tag.
  function tagOf(notification) {
    return String(notification.hints["x-dunst-stack-tag"] ?? notification.hints["x-canonical-private-synchronous"] ?? "");
  }

  // A hidden one is left untracked, so Quickshell drops it; `run` runs for a new one only, not one kept over a reload.
  function arrive(notification) {
    if (ruled(notification).hide) return;
    notification.tracked = true;
    if (!notification.lastGeneration) internal.arrived = Object.assign({}, internal.arrived, { [notification.id]: Date.now() });
    internal.came[notification.id] = ++internal.seq;
    internal.list = internal.list.concat([notification]);
    notification.closed.connect(() => root.leave(notification));
    // A sender replacing it by id changes it in place: its rules and time start again, once for all it changed.
    const renew = () => root.apply(notification);
    for (const changed of [notification.appNameChanged, notification.summaryChanged, notification.bodyChanged, notification.urgencyChanged, notification.expireTimeoutChanged, notification.hintsChanged, notification.actionsChanged]) changed.connect(() => Qt.callLater(renew));
    apply(notification);
    const run = internal.applied[notification.id]?.run;
    if (run && !notification.lastGeneration) runFor(notification, run);
    const over = internal.list.length - settings.keep;
    if (over > 0) internal.list.filter(each => !each.gone && !critical(each)).sort((a, b) => a.id - b.id).slice(0, over).forEach(each => each.expire());
  }

  // Its rules and time, as it comes and as its sender replaces it: one that now hides goes, and its app's card by the same tag gives it its place.
  function apply(notification) {
    if (!internal.list.includes(notification)) return;
    const applied = ruled(notification);
    if (applied.hide) return notification.expire();
    internal.applied = Object.assign({}, internal.applied, { [notification.id]: applied });
    // The sender's new text takes the place of what you sent below its old one.
    if (notification.id in internal.sent) internal.sent = without(internal.sent, notification.id);
    internal.left = Object.assign({}, internal.left, { [notification.id]: timeoutOf(notification) });
    const tag = tagOf(notification);
    for (const old of internal.list) {
      if (!tag || old === notification || old.appName !== notification.appName || tagOf(old) !== tag) continue;
      if (internal.picked === old) internal.picked = notification;
      internal.replaced[old.id] = true;
      old.expire();
    }
  }

  // The pick moves to the card that takes its place; the last one gone lets go of the keys. One closing while replied to stays as a placeholder, its slot and the text kept, until the reply ends.
  function leave(notification) {
    if (notification === internal.replying && !notification.gone) {
      keepClosed(notification);
      const ghost = Object.assign(snapshot(notification), { gone: true, dismiss: () => root.endReply(), expire: () => root.endReply() });
      internal.list = internal.list.map(each => each === notification ? ghost : each);
      internal.replying = internal.picked = ghost;
      return;
    }
    if (!notification.gone && !(notification.id in internal.replaced)) keepClosed(notification);
    const at = shown.indexOf(notification);
    // Nothing reads a gone card's id, so only the list tells; each map loses it in place.
    for (const map of [internal.left, internal.sent, internal.applied, internal.drafts, internal.arrived, internal.replaced, internal.came]) delete map[notification.id];
    internal.list = internal.list.filter(each => each !== notification);
    if (internal.offset > 0 && internal.offset + internal.room > internal.rest.length) internal.offset--;
    if (internal.picked !== notification) return;
    internal.picked = shown[Math.min(at, shown.length - 1)] ?? null;
    if (internal.picked === null) release();
  }

  // Kept to bring back (C-r), unless its sender marked it passing (transient) or it was brought back already.
  function keepClosed(notification) {
    if (!notification.restored && !notification.transient) internal.closed = internal.closed.slice(-19).concat([snapshot(notification)]);
  }

  // What a card shows, kept once its sender is done with it: a placeholder that reads as it did and runs nothing; a picture sent as data goes with its sender.
  function snapshot(notification) {
    return { id: notification.id, summary: notification.summary, body: notification.body, appName: notification.appName, appIcon: notification.appIcon, image: notification.image.startsWith("image://qsimage") ? "" : notification.image, urgency: ["low", "normal", "critical"].indexOf(urgencyOf(notification)), hints: ({ "image-path": notification.hints["image-path"], value: notification.hints.value }), actions: [], arrived: internal.arrived[notification.id] };
  }

  function without(map, id) {
    const rest = Object.assign({}, map);
    delete rest[id];
    return rest;
  }

  Component.onCompleted: check()

  QtObject {
    id: internal

    // A focused fullscreen window holds them as pause does: under it they would expire unseen.
    readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false
    // How many critical ones show pinned; those past them scroll with the rest.
    readonly property int pinned: {
      const critical = root.showable.filter(notification => root.critical(notification)).length;
      return root.showable.length > root.settings.limit ? Math.min(critical, root.settings.limit - 1) : critical;
    }
    readonly property var rest: root.showable.slice(pinned)
    readonly property int room: root.settings.limit - pinned
    property var list: []
    // Milliseconds left by id, counted only while shown and nothing holds them; 0 never expires.
    property var left: ({})
    property bool hovered: false
    property var picked: null
    property var replying: null
    property var sent: ({})
    property var drafts: ({})
    // The last closed, to bring back, and when each came, by id.
    property var closed: []
    property var arrived: ({})
    property bool help: false
    // What the rules matching it set, by id.
    property var applied: ({})
    // The order as it was when it held still, by id.
    property var frozen: []
    // Cards a newer one by their tag replaced, by id: gone, not to bring back.
    property var replaced: ({})
    // The order they came in, by id, one brought back coming again: the newest goes by the corner.
    property var came: ({})
    property int seq: 0
    // The first shown, summoned, past those scrolled by.
    property int offset: 0
    property string error: ""

    function rank(notification) {
      const at = frozen.indexOf(notification.id);
      return at < 0 ? frozen.length + came[notification.id] : at;
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
