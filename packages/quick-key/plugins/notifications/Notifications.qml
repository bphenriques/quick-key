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
  readonly property bool paused: keptPause.value ?? false
  // The cards have the keys (s-n), one surface at a time with the menu and panels.
  readonly property bool summoned: Panels.top === root
  // Summoned or under the pointer, nothing moves and no time runs: those there keep their order, newcomers going after them.
  readonly property bool still: summoned || internal.hovered
  // Critical first, then newest.
  readonly property var atRest: internal.list.slice().sort((a, b) => critical(b) - critical(a) || b.came - a.came)
  // Held still, the order they had then, so a replacement turning one critical moves no digit; newcomers after them.
  readonly property var ordered: {
    if (!internal.holding) return atRest;
    const held = new Set(internal.held);
    return internal.held.filter(entry => internal.list.includes(entry)).concat(internal.list.filter(entry => !held.has(entry)).sort((a, b) => a.came - b.came));
  }
  // Summoned, the held ones show too.
  readonly property var showable: summoned ? ordered : ordered.filter(entry => critical(entry) || !internal.fullscreen && (!paused || !!entry.applied.ignorePause))
  // `limit` at a time, the window following the pick; a card's digit is its place among all, so it holds still.
  readonly property var shown: showable.slice(internal.first, internal.first + settings.limit)
  readonly property int more: showable.length - shown.length
  // None under a fullscreen window: the count would sit over it.
  readonly property int held: internal.fullscreen ? 0 : ordered.length - showable.length
  // What the keys do: the cards', the key list's (`?`), the prompt's, or nothing but ESC once the card you replied to closed.
  readonly property string mode: internal.mode
  readonly property var keys: [
    { key: "1-9", desc: words.helpPick },
    { key: ["Up", "Down"], desc: words.helpMove },
    { key: "Return", desc: words.helpOpen, run: () => !!internal.picked && (open(internal.picked), release(), true) },
    { key: "x", desc: words.helpDismiss, run: () => !!internal.picked && (dismiss(internal.picked), true) },
    { key: "Tab", desc: words.helpReply },
    { key: "Ctrl+Shift+Return", desc: words.helpLeave },
    { key: "Ctrl+X", desc: words.helpClear, run: () => clear() },
    { key: "Ctrl+r", desc: words.helpRestore, run: () => restore() },
    { key: "Ctrl+p", desc: words.helpPause, run: () => togglePause() },
    { key: "Escape", desc: words.helpEscape, run: () => release() }
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
      replyCopied: "Reply copied",
      cardClosed: "Card closed",
      letGo: "let go",
      helpPick: "Pick that card",
      helpMove: "Move the pick",
      helpOpen: "Open it and let go",
      helpLeave: "Send and let go",
      helpDismiss: "Dismiss it",
      helpReply: "Reply",
      helpClear: "Clear all",
      helpRestore: "Bring back the last closed",
      helpPause: "Pause or resume",
      dismiss: "Dismiss",
      helpEscape: "Let go"
    })
  // As a list, for an entry with `list` set to its name: the cards, then the last closed, newest first; choosing one opens it, or brings a closed one back.
  items: atRest.map(entry => itemOf(entry, false)).concat(internal.closed.slice().reverse().map(entry => itemOf(entry, true)))
  empty: words.none
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

  // The app a card names: its sender's, unless a rule renames it, or hides it with "".
  function appOf(entry) {
    return entry.applied.app ?? entry.appName;
  }

  // The app a card or an item names, "" where nothing needs it: a name a rule sets always shows; else not when the title says it as a whole word ("Go" is not in "Good") or its icon shows it, so a song's cover keeps it.
  function appShown(entry, title, iconShown) {
    const app = appOf(entry);
    const words = text => " " + text.toLowerCase().replace(/[\s!-\/:-@[-`{-~]+/g, " ").trim() + " ";
    return entry.applied.app === undefined && (iconShown || words(title).includes(words(app))) ? "" : app;
  }

  // What sits beside a card's or an item's title: how many times it came, its app where nothing else names it, and when.
  function asideOf(entry, title, iconShown, when) {
    return [entry.repeats > 1 ? "×" + entry.repeats : "", appShown(entry, title, iconShown), when].filter(part => part).join(" · ");
  }

  // Its sender's, unless a rule sets another.
  function urgencyOf(entry) {
    return entry.applied.urgency ?? settings.urgencies[entry.urgency] ?? "normal";
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

  // However the keys go (ESC, the menu opening over the cards), the reply, the scroll and the pick go with them; back from the menu, the pick lands on a card that shows, once what shows has followed.
  onSummonedChanged: {
    if (summoned) {
      // At once where what shows is known already, and again once it has followed.
      if (!shown.includes(internal.picked)) internal.picked = newest();
      Qt.callLater(() => {
        if (summoned && !shown.includes(internal.picked)) internal.picked = newest();
      });
      return;
    }
    internal.mode = "cards";
    internal.replying = null;
    internal.picked = null;
    internal.offset = 0;
  }

  onStillChanged: {
    if (still) internal.held = atRest;
    internal.holding = still;
  }

  // The newest card on screen, which a binding acts on and summoning picks.
  function newest() {
    return shown.reduce((found, entry) => found === null || entry.came > found.came ? entry : found, null);
  }

  // A rule's `default`, else its app to the front and its own default action, else dismissed: a click means done with it; one brought back is only to read.
  function open(entry) {
    if (entry === internal.replying) endReply();
    if (entry.restored) return dismiss(entry);
    if (entry.applied.default) {
      runFor(entry, entry.applied.default);
      return dismiss(entry);
    }
    // Its app to the front too, as its own default can rarely raise it: Wayland lets a window take focus only when the compositor gives it.
    Compositor.focusApp([entry.desktopEntry, entry.appName]);
    const action = Array.from(entry.actions).find(action => action.identifier === "default");
    if (action) action.invoke();
    else dismiss(entry);
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

  // Emptied at once, then each closed: one by one, every card would sort the rest again.
  function clear() {
    endReply();
    const all = internal.list;
    internal.list = [];
    // The closed history built aside and set once: set per card, all that reads it would follow each.
    internal.building = internal.closed;
    for (const entry of all) {
      if (entry.notification) entry.notification.dismiss();
      else leave(entry);
    }
    internal.closed = internal.building;
    internal.building = null;
  }

  // The pointer is on a card: every one holds still, so the one under it stays there.
  function hold(on) {
    internal.hovered = on;
  }

  // Its reply first, on TAB, then its rules' actions on their keys, then its sender's but the default, each with a letter its label offers, else any, that neither those nor `x`, which dismisses, take.
  function actionsOf(entry) {
    if (!entry || entry.restored) return [];
    const values = valuesOf(entry);
    const ruled = Array.from(entry.applied.actions).map(action => ({ desc: action.desc.replace(/\{(\w+)\}/g, (all, name) => values[name] ?? all), key: action.key, glyph: action.icon ?? "", run: () => {
        root.runFor(entry, action.cmd);
        if (action.closes !== false) root.dismiss(entry);
      } }));
    const actions = Array.from(entry.actions).filter(action => action.identifier !== "default");
    const keys = MenuKeys.assign(actions.map(action => action.text), ["x"].concat(ruled.map(action => action.key)), "abcdefghijklmnopqrstuvwxyz");
    // A sender that says its actions are icons (action-icons) names one by each's identifier.
    const own = actions.map((action, i) => ({ desc: action.text, key: keys[i], source: entry.hints["action-icons"] ? Quickshell.iconPath(action.identifier + "-symbolic", true) || Quickshell.iconPath(action.identifier, true) : "", run: () => action.invoke() }));
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
    // A replacement took its reply away just now, before the card heard: as if it closed.
    if (!entry.hasInlineReply) {
      entry.draft = text;
      return interrupt();
    }
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

  // A card that closed, the last by default, back in the stack as the newest until dismissed, only to read: its sender is done with it.
  function restore(entry = internal.closed[internal.closed.length - 1]) {
    if (!entry) return;
    internal.closed = internal.closed.filter(each => each !== entry);
    entry.came = ++internal.seq;
    entry.timeout = 0;
    internal.list = internal.list.concat([entry]);
    if (summoned && !internal.replying) pick(entry);
  }

  // A card as a list's item, by when it came: its title, its app and time aside, struck once closed.
  function itemOf(entry, closed) {
    const app = appOf(entry);
    const title = entry.summary || app || entry.appName;
    const when = entry.arrived ? Clock.recent(new Date(entry.arrived)) : "";
    const detail = asideOf(entry, title, false, when);
    return {
      id: String(entry.came),
      label: title,
      // Critical by its glyph too, not by colour alone.
      icon: critical(entry) ? Glyphs.urgent : Glyphs.notifications,
      detail: detail,
      tone: critical(entry) ? "alert" : "",
      done: closed,
      closes: true,
      actions: closed ? [] : [{ key: "x", desc: words.dismiss, icon: Glyphs.close }]
    };
  }

  function select(id) {
    const live = internal.list.find(entry => String(entry.came) === id);
    if (live) return open(live);
    restore(internal.closed.find(entry => String(entry.came) === id) ?? null);
  }

  function run(id, key) {
    const live = internal.list.find(entry => String(entry.came) === id);
    if (live && key === "x") dismiss(live);
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
    else {
      // Its own keys, as `?` lists them, then the picked card's actions.
      const own = keys.find(entry => entry.run && entry.key === name);
      if (own) return own.run() !== false;
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
    return String(entry.hints["image-path"] ?? entry.hints["image_path"] ?? "") || entry.appIcon || "";
  }

  // Its icon as a path when it is a file, else "".
  function fileOf(entry) {
    const icon = iconOf(entry);
    if (icon.startsWith("/")) return icon;
    const path = icon.replace(/^file:\/\/(localhost)?(?=\/)/, "");
    if (path === icon) return "";
    try {
      return decodeURIComponent(path);
    } catch (error) {
      return path;
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
    // Within what a timer holds, and a millisecond at least, as a fraction of one would round to 0, never.
    if (entry.applied.timeout !== undefined) return entry.applied.timeout > 0 ? Math.min(2147483647, Math.max(1, Math.round(entry.applied.timeout * 1000))) : 0;
    if (critical(entry)) return 0;
    if (entry.expireTimeout >= 0) return entry.expireTimeout;
    return 1000 * (urgencyOf(entry) === "low" ? settings.timeout.low : settings.timeout.normal);
  }

  // Volume and brightness tools replace their last one by a tag; one that is no text (a bare true) names nothing.
  function tagOf(notification) {
    const tag = notification.hints["x-dunst-stack-tag"] ?? notification.hints["x-canonical-private-synchronous"];
    return typeof tag === "string" ? tag : "";
  }

  // A hidden one is left untracked, so Quickshell drops it; one by the tag of a card from its app takes that card, as a replacement by id does; `run` runs for a new one only, not one kept over a reload.
  function arrive(notification) {
    const applied = ruled(notification);
    const tag = tagOf(notification);
    // Its card, by tag, else one saying exactly what it says (no tag on either, no reply on it), which it renews and counts, as dunst stacks duplicates.
    const same = tag ? internal.list.find(each => each.notification?.appName === notification.appName && tagOf(each.notification) === tag) : internal.list.find(each => each !== internal.replying && each.notification && !tagOf(each.notification) && each.appName === notification.appName && each.summary === notification.summary && each.body === notification.body) ?? null;
    // A replacement by tag that a rule hides still takes its card, so the card goes with it; a duplicate it hides leaves its twin be.
    if (applied.hide && !(same && tag)) return;
    notification.tracked = true;
    const entry = same ?? entryOf.createObject(root, { came: ++internal.seq, arrived: notification.lastGeneration ? 0 : Date.now() });
    const old = entry.notification;
    entry.notification = notification;
    notification.closed.connect(() => {
      if (entry.notification === notification) root.leave(entry);
    });
    if (old) {
      // A repeat is a new arrival: it comes to the front unless the cards hold still, and its rule's run runs again.
      if (!tag) {
        entry.repeats++;
        entry.arrived = Date.now();
        if (!still) entry.came = ++internal.seq;
        if (entry.timer.running) entry.timer.restart();
        if (applied.run && !notification.lastGeneration) runFor(entry, applied.run);
      }
      return old.expire();
    }
    internal.list = internal.list.concat([entry]);
    apply(entry, applied);
    if (applied.run && !notification.lastGeneration) runFor(entry, applied.run);
    // Silent, it goes straight to those closed, to read later, as it was only ever meant to.
    if (applied.silent) {
      leave(entry);
      return notification.expire();
    }
    if (summoned && !internal.picked) pick(entry);
    // At most `keep`, the oldest closing first and critical ones last; never the one that just came, the one you reply to, or, held still, one on screen.
    const over = internal.list.length - settings.keep;
    if (over > 0) internal.list.filter(each => each !== entry && each !== internal.replying && !(still && shown.includes(each))).sort((a, b) => critical(a) - critical(b) || a.came - b.came).slice(0, over).forEach(each => root.expire(each));
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

  // The pick moves to the card that takes its place; the last one gone lets go of the keys. The card you reply to closing interrupts the reply. Kept to bring back (C-r), unless its sender marked it passing (transient); one brought back goes back.
  function leave(entry, keep = true) {
    if (entry === internal.replying) interrupt();
    const at = shown.indexOf(entry);
    internal.list = internal.list.filter(each => each !== entry);
    if (internal.picked === entry) {
      internal.picked = shown[at < 0 ? 0 : Math.min(at, shown.length - 1)] ?? null;
      if (internal.picked === null && internal.mode !== "closed") release();
    }
    if (!keep || entry.notification?.transient) return entry.destroy();
    if (!entry.restored) entry.saved = snapshot(entry);
    entry.notification = null;
    // Its earlier self goes, by tag or by saying the same, so a chatty sender (a volume tool, a silent rule) never pushes the rest out.
    const twin = each => each.appName === entry.appName && (tagOf(entry.data) ? tagOf(each.data) === tagOf(entry.data) : each.summary === entry.summary && each.body === entry.body);
    const history = internal.building ?? internal.closed;
    history.filter(twin).forEach(each => each.destroy());
    const closed = history.filter(each => !twin(each)).concat([entry]);
    while (closed.length > settings.history) closed.shift().destroy();
    if (internal.building) internal.building = closed;
    else internal.closed = closed;
  }

  // What a card shows, kept once its sender is done with it; a picture sent as data goes with its sender.
  function snapshot(entry) {
    return { id: entry.id, summary: entry.summary, body: entry.body, appName: entry.appName, appIcon: entry.appIcon, image: entry.image.startsWith("image://qsimage") ? "" : entry.image, urgency: entry.urgency, hints: ({ "image-path": entry.hints["image-path"], value: entry.hints.value, "x-dunst-stack-tag": tagOf(entry) }), desktopEntry: entry.desktopEntry, expireTimeout: -1 };
  }

  // Those closed come back over a restart, as Kept holds them, never a picture's data; kept from here on, as the list's first value is told as a change too.
  Component.onCompleted: {
    const kept = Array.from(Kept.value(name + ".closed") ?? []);
    internal.closed = kept.slice(Math.max(0, kept.length - settings.history)).map(each => entryOf.createObject(root, Object.assign({ came: ++internal.seq }, each)));
    internal.closedChanged.connect(() => Kept.set(name + ".closed", internal.closed.map(entry => ({ saved: entry.saved, arrived: entry.arrived, repeats: entry.repeats, applied: entry.applied }))));
    refresh();
  }

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
    property int repeats: 1
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
  }

  Component {
    id: entryOf

    Entry {
      plugin: root
    }
  }

  KeptValue {
    id: keptPause
    key: root.name + ".paused"
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
    property var closed: []
    // While clearing, the closed history being built.
    property var building: null
    property bool hovered: false
    property var picked: null
    property var replying: null
    property string mode: "cards"
    property bool copied: false
    property int seq: 0
    // Held still, and the order then.
    property bool holding: false
    property var held: []
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
    // Your input alone: keep awake or a playing video inhibit idle, and the cards would then expire with no one there.
    respectInhibitors: false
    enabled: root.settings.idle > 0
    timeout: root.settings.idle
  }
}
