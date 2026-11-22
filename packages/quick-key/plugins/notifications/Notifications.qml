pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Services.Notifications
import Quickshell.Wayland
import qs
import qs.services
import qs.ui

// A notification server: Quickshell speaks the protocol; this decides what shows and for how long, and Cards.qml draws it. Each card is an Entry, which a replacement updates in place.
Plugin {
  id: root

  views: ["Cards.qml"]

  // Kept over a reload, as keep awake is.
  readonly property bool paused: Kept.values[name + ".paused"] ?? false
  // The cards have the keys (s-n), one surface at a time with the menu and panels.
  readonly property bool summoned: Panels.top === root
  // Summoned or under the pointer, nothing moves and no time runs: those there keep their order, newcomers going after them.
  readonly property bool still: summoned || internal.hovered
  readonly property var ordered: {
    const atRest = internal.list.slice().sort((a, b) => critical(b) - critical(a) || b.came - a.came);
    if (!still) return atRest;
    return atRest.filter(entry => entry.came <= internal.heldAt).concat(internal.list.filter(entry => entry.came > internal.heldAt).sort((a, b) => a.came - b.came));
  }
  // Summoned, the held ones show too.
  readonly property var showable: summoned ? ordered : ordered.filter(entry => critical(entry) || !internal.fullscreen && (!paused || !!entry.applied.ignorePause))
  // `limit` at a time, the window following the pick; a card's digit is its place among all, so it holds still.
  readonly property var shown: showable.slice(internal.first, internal.first + settings.limit)
  // Those showable but not shown.
  readonly property int more: showable.length - shown.length
  // None under a fullscreen window: the count would sit over it.
  readonly property int held: internal.fullscreen ? 0 : ordered.length - showable.length
  // What the keys do: the cards', the key list's (`?`), the prompt's, or nothing but ESC once the card you replied to closed.
  readonly property string mode: internal.mode
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
  // The card the keys act on while summoned, and the one replied to, its prompt in its actions' place.
  readonly property var picked: internal.picked
  readonly property var replying: internal.replying
  // The reply whose card closed went to the clipboard; else it was empty.
  readonly property bool copied: internal.copied

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
      sendLeave: "send, go",
      replyCopied: "reply copied",
      cardClosed: "card closed",
      letGo: "let go",
      helpPick: "Pick that card",
      helpMove: "Move the pick",
      helpOpen: "Open it and let go",
      helpLeave: "Send and let go",
      helpDismiss: "Dismiss it",
      helpReply: "Reply",
      helpClear: "Clear all",
      helpRestore: "Bring back the last closed",
      helpPause: "Pause or resume"
    })
  actions: ({
      summon: { icon: () => Glyphs.notifications, available: () => true, run: () => root.summon() },
      pause: { icon: () => root.glyph, state: root.name, available: () => true, run: () => root.togglePause() },
      clear: { icon: () => Glyphs.close, available: () => internal.list.length > 0, run: () => root.clear() },
      dismiss: { icon: () => Glyphs.close, available: () => root.newest() !== null, run: () => root.dismiss(root.newest()) },
      invoke: { icon: () => Glyphs.notifications, available: () => root.newest() !== null, run: () => root.open(root.newest()) },
      restore: { icon: () => Glyphs.notifications, available: () => internal.closed.length > 0, run: () => root.restore() }
    })

  function critical(entry) {
    return urgencyOf(entry) === "critical";
  }

  // Its sender's, unless a rule sets another.
  function urgencyOf(entry) {
    return entry.applied.urgency ?? settings.urgencies[entry.urgency];
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
    Panels.open(root);
    internal.picked = newest();
  }

  function release() {
    if (summoned) Panels.back();
  }

  // However the keys go (ESC, the menu opening over the cards), the reply, the scroll and the pick go with them; back from the menu, the pick lands on a card that shows.
  onSummonedChanged: {
    if (summoned) {
      if (!shown.includes(internal.picked)) internal.picked = newest();
      return;
    }
    internal.mode = "cards";
    internal.replying = null;
    internal.picked = null;
    internal.offset = 0;
  }

  onStillChanged: if (still) internal.heldAt = internal.seq

  // The newest card on screen, which a binding acts on and summoning picks.
  function newest() {
    return shown.reduce((found, entry) => found === null || entry.came > found.came ? entry : found, null);
  }

  // A rule's `default`, else its own default action, else dismissed: a click means done with it; one brought back is only to read.
  function open(entry) {
    if (entry === internal.replying) endReply();
    const action = entry.restored ? null : Array.from(entry.actions).find(action => action.identifier === "default");
    if (entry.applied.default && !entry.restored) {
      runFor(entry, entry.applied.default);
      dismiss(entry);
    } else if (action) {
      action.invoke();
    } else {
      dismiss(entry);
    }
  }

  // The card you reply to, by a click: the reply ends first, so nothing is copied.
  function dismiss(entry) {
    if (entry === internal.replying) endReply();
    if (entry.notification) entry.notification.dismiss();
    else leave(entry);
  }

  function expire(entry) {
    if (entry.notification) entry.notification.expire();
    else leave(entry);
  }

  function clear() {
    endReply();
    for (const entry of internal.list.slice()) dismiss(entry);
  }

  // The pointer is on a card: every one holds still, so the one under it stays there.
  function hold(on) {
    internal.hovered = on;
  }

  // Its reply first, on TAB, then its rules' actions on their keys, then its sender's but the default, each with a letter its label offers, else any, that neither those nor `x`, which dismisses, take.
  function actionsOf(entry) {
    if (!entry || entry.restored) return [];
    const values = valuesOf(entry);
    const ruled = Array.from(entry.applied.actions).map(action => ({ desc: action.desc.replace(/\{(\w+)\}/g, (all, name) => values[name] ?? all), key: action.key, run: () => {
        root.runFor(entry, action.cmd);
        if (action.closes !== false) root.dismiss(entry);
      } }));
    const actions = Array.from(entry.actions).filter(action => action.identifier !== "default");
    const keys = MenuKeys.assign(actions.map(action => action.text), ["x"].concat(ruled.map(action => action.key)), "abcdefghijklmnopqrstuvwxyz");
    const own = actions.map((action, i) => ({ desc: action.text, key: keys[i], run: () => action.invoke() }));
    const reply = entry.hasInlineReply ? [{ desc: Words.replyPrompt, key: "Tab", run: () => root.reply(entry) }] : [];
    return reply.concat(ruled, own);
  }

  // Its prompt in its actions' place, summoned and picked; a click on Reply... starts here too.
  function reply(entry) {
    summon();
    pick(entry);
    internal.replying = entry;
    internal.mode = "reply";
  }

  function endReply() {
    if (internal.mode === "reply") internal.mode = "cards";
    internal.replying = null;
  }

  // The reply can no longer reach its card: your text to the clipboard, and the keys held until ESC, so the rest of what you type goes nowhere.
  function interrupt() {
    const draft = internal.replying.draft;
    if (draft) Quickshell.clipboardText = draft;
    internal.copied = draft !== "";
    internal.replying = null;
    internal.mode = "closed";
  }

  function keepDraft(entry, text) {
    if (entry) entry.draft = text;
  }

  // The keys stay only on a resident card.
  function sendReply(text, close) {
    const entry = internal.replying;
    if (!entry || text.trim() === "") return;
    entry.draft = "";
    // No longer the reply target, so if the reply closes it, it is kept to bring back.
    endReply();
    entry.notification.sendInlineReply(text);
    if (close || !entry.resident) release();
  }

  // ↑↓ as they show: newest by the corner, so at a bottom one Down goes toward it; the window follows.
  function move(down) {
    const by = down === settings.corner.startsWith("top") ? 1 : -1;
    pick(showable[showable.indexOf(internal.picked) + by]);
  }

  // A card by its digit, its place among all, scrolled into view.
  function pick(entry) {
    if (!entry) return false;
    internal.picked = entry;
    internal.offset = internal.first;
    return true;
  }

  // The last card that closed, back in the stack as the newest, only to read: its sender is done with it.
  function restore() {
    const entry = internal.closed[internal.closed.length - 1];
    if (!entry) return;
    internal.closed = internal.closed.slice(0, -1);
    entry.came = ++internal.seq;
    entry.timeout = timeoutOf(entry);
    internal.list = internal.list.concat([entry]);
    if (summoned && !internal.replying) pick(entry);
  }

  // When it came, once it has waited a minute or more (held by pause, idle or a fullscreen window): so an old one never reads as new.
  function ageOf(entry) {
    return entry.arrived && Clock.date - entry.arrived >= 60000 ? Clock.time(new Date(entry.arrived)) : "";
  }

  // Whether its time runs: shown, nothing holding the cards, no unsent reply on it.
  function counting(entry) {
    return !still && !idle.isIdle && entry.timeout > 0 && !entry.draft && shown.includes(entry);
  }

  function key(name) {
    if (internal.mode === "closed") {
      if (name === "Escape") release();
      return true;
    }
    // The prompt has the keys: what it leaves (arrows, chords) would act on the cards under the text; Escape, from a binding, still lets go.
    if (internal.mode === "reply" && name !== "Escape") return false;
    if (internal.mode === "help") internal.mode = "cards";
    else if (name === "?") internal.mode = "help";
    else if (/^[1-9]$/.test(name)) return pick(showable[Number(name) - 1]);
    else if (name === "Up" || name === "Down") move(name === "Down");
    else if (name === "Return" && internal.picked) {
      open(internal.picked);
      release();
    } else if (name === "x" && internal.picked) dismiss(internal.picked);
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
      urgency: settings.urgencies[notification.urgency],
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
  function valuesOf(entry) {
    return Object.assign({ app: entry.appName, summary: entry.summary, body: entry.body, urgency: urgencyOf(entry), id: String(entry.id), icon: fileOf(entry) || iconOf(entry) }, entry.applied.values);
  }

  // Its icon as sent: a file or a name, from its image-path hint (notify-send -i), else its app icon (niri's screenshot).
  function iconOf(entry) {
    return String(entry.hints["image-path"] ?? "") || entry.appIcon || "";
  }

  // Its icon as a path when it is a file, else "".
  function fileOf(entry) {
    const icon = iconOf(entry);
    if (icon.startsWith("/")) return icon;
    if (!icon.startsWith("file://")) return "";
    try {
      return decodeURIComponent(icon.slice(7));
    } catch (error) {
      return icon.slice(7);
    }
  }

  // A rule's command, given them in its environment as NOTIFICATION_<NAME>, as dunst gives DUNST_*.
  function runFor(entry, cmd) {
    const environment = {};
    for (const [name, value] of Object.entries(valuesOf(entry))) environment["NOTIFICATION_" + name.toUpperCase()] = value;
    Commands.runWith(cmd, environment);
  }

  // Milliseconds it shows: a rule's, else 0 for a critical one, else its sender's, which Quickshell passes as the protocol does, in milliseconds; else its urgency's.
  function timeoutOf(entry) {
    if (entry.applied.timeout !== undefined) return entry.applied.timeout * 1000;
    if (critical(entry)) return 0;
    if (entry.expireTimeout >= 0) return entry.expireTimeout;
    return 1000 * (urgencyOf(entry) === "low" ? settings.timeout.low : settings.timeout.normal);
  }

  // Volume and brightness tools replace their last one by a tag.
  function tagOf(notification) {
    return String(notification.hints["x-dunst-stack-tag"] ?? notification.hints["x-canonical-private-synchronous"] ?? "");
  }

  // A hidden one is left untracked, so Quickshell drops it; one by the tag of a card from its app takes that card, as a replacement by id does; `run` runs for a new one only, not one kept over a reload.
  function arrive(notification) {
    const applied = ruled(notification);
    if (applied.hide) return;
    notification.tracked = true;
    const tag = tagOf(notification);
    const same = tag ? internal.list.find(each => each.notification?.appName === notification.appName && tagOf(each.notification) === tag) : null;
    const entry = same ?? entryOf.createObject(root, { came: ++internal.seq, arrived: notification.lastGeneration ? 0 : Date.now() });
    const old = entry.notification;
    entry.notification = notification;
    notification.closed.connect(() => {
      if (entry.notification === notification) root.leave(entry);
    });
    if (old) return old.expire();
    internal.list = internal.list.concat([entry]);
    apply(entry, applied);
    if (summoned && !internal.picked) pick(entry);
    if (applied.run && !notification.lastGeneration) runFor(entry, applied.run);
    // At most `keep`, the oldest closing first, never one that must not be missed or that you reply to.
    const over = internal.list.length - settings.keep;
    if (over > 0) internal.list.filter(each => !critical(each) && each !== internal.replying).sort((a, b) => a.came - b.came).slice(0, over).forEach(each => root.expire(each));
  }

  // Its rules and time, as it comes and as its sender replaces it, by id or tag: one that now hides goes, not to bring back; one that now takes no reply ends yours.
  function apply(entry, applied) {
    if (applied.hide) {
      const notification = entry.notification;
      entry.notification = null;
      leave(entry, false);
      return notification.expire();
    }
    entry.applied = applied;
    entry.timeout = timeoutOf(entry);
    if (entry.timer.running) entry.timer.restart();
    if (entry === internal.replying && !entry.hasInlineReply) interrupt();
  }

  // The pick moves to the card that takes its place; the last one gone lets go of the keys. The card you reply to closing interrupts the reply. Kept to bring back (C-r), unless its sender marked it passing (transient) or it was brought back already.
  function leave(entry, keep = true) {
    if (entry === internal.replying) interrupt();
    const at = shown.indexOf(entry);
    internal.list = internal.list.filter(each => each !== entry);
    if (internal.picked === entry) {
      internal.picked = shown[at < 0 ? 0 : Math.min(at, shown.length - 1)] ?? null;
      if (internal.picked === null && internal.mode !== "closed") release();
    }
    if (!keep || entry.restored || entry.notification.transient) return entry.destroy();
    entry.saved = snapshot(entry);
    entry.notification = null;
    const closed = internal.closed.concat([entry]);
    if (closed.length > 20) closed.shift().destroy();
    internal.closed = closed;
  }

  // What a card shows, kept once its sender is done with it; a picture sent as data goes with its sender.
  function snapshot(entry) {
    return { id: entry.id, summary: entry.summary, body: entry.body, appName: entry.appName, appIcon: entry.appIcon, image: entry.image.startsWith("image://qsimage") ? "" : entry.image, urgency: entry.urgency, hints: ({ "image-path": entry.hints["image-path"], value: entry.hints.value }), desktopEntry: entry.desktopEntry, expireTimeout: -1 };
  }

  Component.onCompleted: check()

  // A card: its notification while its sender keeps it, else what it showed; when it came, what its rules set, your unsent reply, and its time.
  component Entry: QtObject {
    id: entry

    required property var plugin
    property var notification: null
    property var saved: null
    readonly property var data: notification ?? saved
    readonly property bool restored: notification === null
    readonly property int id: data?.id ?? 0
    readonly property string summary: data?.summary ?? ""
    readonly property string body: data?.body ?? ""
    readonly property string appName: data?.appName ?? ""
    readonly property string appIcon: data?.appIcon ?? ""
    readonly property string image: data?.image ?? ""
    readonly property var hints: data?.hints ?? ({})
    readonly property int urgency: data?.urgency ?? 1
    readonly property string desktopEntry: data?.desktopEntry ?? ""
    readonly property int expireTimeout: data?.expireTimeout ?? -1
    readonly property var actions: notification?.actions ?? []
    readonly property bool hasInlineReply: notification?.hasInlineReply ?? false
    readonly property bool resident: notification?.resident ?? false
    property int came: 0
    property real arrived: 0
    property var applied: ({ actions: [], values: {} })
    property string draft: ""
    property int timeout: 0
    // What a replacement changes, by id or tag: once for all of it, its rules and time again.
    readonly property string signature: notification ? [notification.id, notification.appName, notification.summary, notification.body, notification.urgency, notification.expireTimeout, JSON.stringify(notification.hints), Array.from(notification.actions).map(action => action.identifier).join()].join("\n") : ""
    readonly property var renew: () => {
      if (entry.notification && entry.plugin.ordered.includes(entry)) entry.plugin.apply(entry, entry.plugin.ruled(entry.notification));
    }
    onSignatureChanged: Qt.callLater(renew)

    // Restarting in full whenever it runs again: after a hover, a summon, idle.
    property Timer timer: Timer {
      interval: Math.max(1, entry.timeout)
      running: entry.plugin.counting(entry)
      onTriggered: entry.plugin.expire(entry)
    }

    function dismiss() {
      plugin.dismiss(entry);
    }

    function expire() {
      plugin.expire(entry);
    }
  }

  Component {
    id: entryOf

    Entry {
      plugin: root
    }
  }

  QtObject {
    id: internal

    // A focused fullscreen window holds them as pause does: under it they would expire unseen.
    readonly property bool fullscreen: ToplevelManager.activeToplevel?.fullscreen ?? false
    // The first shown: `offset`, within the list, moved just enough to show the pick.
    readonly property int first: {
      const at = root.showable.indexOf(picked);
      const within = Math.max(0, Math.min(offset, root.showable.length - root.settings.limit));
      return at < 0 ? within : Math.max(at - root.settings.limit + 1, Math.min(within, at));
    }
    property var list: []
    // The last closed, to bring back.
    property var closed: []
    property bool hovered: false
    property var picked: null
    property var replying: null
    property string mode: "cards"
    property bool copied: false
    // Arrivals counted; the count when the cards last held still.
    property int seq: 0
    property int heldAt: 0
    property int offset: 0
    property string error: ""
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
}
