.pragma library

// What a card shows, for how long and in what order, pure: each reads a card's fields (Entry's), so a unit test gives it plain objects (tests/unit).

var urgencies = ["low", "normal", "critical"];

// What the rules that match a notification set, in order, later ones winning, actions adding up but one on a key taken before replacing it; `values` the text its named groups found, as `groupNames` names them.
function rules(notification, list, groupNames) {
  const fields = {
    app: notification.appName,
    summary: notification.summary,
    body: notification.body,
    category: String(notification.hints.category ?? ""),
    urgency: urgencies[notification.urgency],
    desktopEntry: notification.desktopEntry
  };
  const applied = { actions: [], values: {} };
  for (const rule of Array.from(list)) {
    const values = {};
    const matched = Object.entries(rule.match ?? {}).every(([field, pattern]) => {
      const found = new RegExp(pattern).exec(fields[field] ?? "");
      groupNames(pattern).forEach((name, i) => {
        if (found && name) values[name] = found[i + 1] ?? "";
      });
      return found !== null;
    });
    if (!matched) continue;
    const actions = Array.from(rule.actions ?? []);
    const kept = applied.actions.filter(action => !actions.some(other => other.key === action.key));
    Object.assign(applied, rule, { actions: kept.concat(actions), values: Object.assign(applied.values, values) });
  }
  return applied;
}

// Its sender's, unless a rule sets another.
function urgency(entry) {
  return entry.applied.urgency ?? urgencies[entry.urgency] ?? "normal";
}

function critical(entry) {
  return urgency(entry) === "critical";
}

// Milliseconds it shows: a rule's, else 0 for a critical one, else its sender's, which Quickshell passes as the protocol does, in milliseconds; else its urgency's, in seconds (`timeouts`).
function timeout(entry, timeouts) {
  // Within what a timer holds, and a millisecond at least, as a fraction of one would round to 0, never.
  if (entry.applied.timeout !== undefined) return entry.applied.timeout > 0 ? Math.min(2147483647, Math.max(1, Math.round(entry.applied.timeout * 1000))) : 0;
  if (critical(entry)) return 0;
  if (entry.expireTimeout >= 0) return entry.expireTimeout;
  return 1000 * (urgency(entry) === "low" ? timeouts.low : timeouts.normal);
}

// The app a card names: its sender's, unless a rule renames it, or hides it with "".
function app(entry) {
  return entry.applied.app ?? entry.appName;
}

// The app a card or an item names, "" where nothing needs it: a name a rule sets always shows; else not when the title says it as a whole word ("Go" is not in "Good") or its icon shows it, so a song's cover keeps it.
function appShown(entry, title, iconShown) {
  const words = text => " " + text.toLowerCase().replace(/[\s!-\/:-@[-`{-~]+/g, " ").trim() + " ";
  return entry.applied.app === undefined && (iconShown || words(title).includes(words(app(entry)))) ? "" : app(entry);
}

// Its icon as sent: a file or a name, from its image-path hint (notify-send -i), else its app icon (niri's screenshot).
function icon(entry) {
  return String(entry.hints["image-path"] ?? entry.hints["image_path"] ?? "") || entry.appIcon || "";
}

// Its icon as a path when it is a file, else "".
function iconFile(entry) {
  const sent = icon(entry);
  if (sent.startsWith("/")) return sent;
  const path = sent.replace(/^file:\/\/(localhost)?(?=\/)/, "");
  if (path === sent) return "";
  try {
    return decodeURIComponent(path);
  } catch (error) {
    return path;
  }
}

// Volume and brightness tools replace their last one by a tag; one that is no text (a bare true) names nothing.
function tag(entry) {
  const found = entry.hints["x-dunst-stack-tag"] ?? entry.hints["x-canonical-private-synchronous"];
  return typeof found === "string" ? found : "";
}

// Whether `other` stands for what `entry` says: from its app, by its tag when it has one, else by its summary and body.
function twin(entry, other) {
  return other.appName === entry.appName && (tag(entry) ? tag(other) === tag(entry) : other.summary === entry.summary && other.body === entry.body);
}

// Critical first, then newest.
function atRest(list) {
  return list.slice().sort((a, b) => critical(b) - critical(a) || b.came - a.came);
}

// Held still, the order they had then (`held`), so a replacement turning one critical moves no digit; newcomers after them.
function heldOrder(list, held) {
  const kept = new Set(held);
  return held.filter(entry => list.includes(entry)).concat(list.filter(entry => !kept.has(entry)).sort((a, b) => a.came - b.came));
}

// Those to close past `keep`, the oldest first and critical ones last, never one `spared`.
function evicted(list, keep, spared) {
  const over = list.length - keep;
  return over > 0 ? list.filter(entry => !spared.includes(entry)).sort((a, b) => critical(a) - critical(b) || a.came - b.came).slice(0, over) : [];
}

// The card that takes the place of one gone among those shown (`before` it went, `after`), else the first; null when none shows.
function successor(entry, before, after) {
  const at = before.indexOf(entry);
  return after[at < 0 ? 0 : Math.min(at, after.length - 1)] ?? null;
}
