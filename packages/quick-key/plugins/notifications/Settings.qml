import QtQuick
import qs

// The notifications' settings (docs/src/plugins.md#notifications); `owner` the one tool it names, the standard busctl.
PluginSettings {
  // The corner the cards stack in: top-right, top-left, bottom-right or bottom-left; by default, on the right, away from the menu's edge.
  property string corner: Config.atTop ? "bottom-right" : "top-right"
  // Cards shown at once, 1 to 9; the rest wait, counted.
  property int limit: 3
  // Seconds a card shows when its sender sets no time, by urgency; one set alone leaves the other at its default; a critical card stays until dismissed.
  property var timeout: ({ low: 3, normal: 8 })
  // Notifications kept at most, shown or waiting, no fewer than `limit`; past it the oldest close, critical ones last.
  property int keep: 100
  // The side of a card its actions sit on: right or left.
  property string actionSide: "right"
  // A card's width, in pixels, never past the screen.
  property int width: 480
  // The cards' distance from the screen's edge, in pixels.
  property int margin: Config.theme.edgeMargin
  // Shows the plugin's `shortcut` dimly by the cards at rest, to teach it.
  property bool hint: true
  // Seconds without input after which no card's time runs, so none goes while you are away; 0 lets time run.
  property int idle: 120
  // Each { match, app, icon, hide, silent, timeout, urgency, ignorePause, actions, default, run }, applied in order (docs/src/plugins.md#rules).
  property var rules: []
  // Prints the process id holding the notifications' name on the session bus, last on its line, so another daemon there shows as the plugin's error.
  property string owner: "busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.Notifications"

  readonly property var corners: ["top-right", "top-left", "bottom-right", "bottom-left"]
  readonly property var sides: ["right", "left"]
  readonly property var fields: ["app", "summary", "body", "category", "urgency", "desktopEntry"]
  readonly property var ruleKinds: ({ match: "map", app: "string", hide: "boolean", timeout: "number", urgency: "string", ignorePause: "boolean", actions: "list", default: "string", run: "string", icon: "string", silent: "boolean" })
  readonly property var actionKinds: ({ key: "string", desc: "string", cmd: "string", closes: "boolean", icon: "string" })
  // What its commands get as NOTIFICATION_<NAME>, so a group by one of these names would hide it.
  readonly property var given: ["app", "summary", "body", "urgency", "id", "icon"]
  readonly property var urgencies: ["low", "normal", "critical"]

  function problems() {
    const found = [];
    if (!corners.includes(corner)) found.push("sets corner to '" + corner + "', none of " + corners.join(", "));
    if (!sides.includes(actionSide)) found.push("sets actionSide to '" + actionSide + "', none of " + sides.join(", "));
    if (limit < 1 || limit > 9) found.push("sets limit to " + limit + ", not 1 to 9, as many as there are digits");
    if (idle < 0) found.push("sets idle below 0");
    if (margin < 0) found.push("sets margin below 0");
    if (keep < limit) found.push("sets keep to " + keep + ", below limit");
    found.push(...Object.keys(timeout ?? {}).filter(urgency => !["low", "normal"].includes(urgency)).map(urgency => "sets timeout." + urgency + ", none of low, normal"));
    for (const urgency of ["low", "normal"]) {
      if (typeof timeout?.[urgency] !== "number" || timeout[urgency] < 0) found.push("sets timeout." + urgency + " to no number of seconds");
    }
    Array.from(rules).forEach((rule, i) => found.push(...ruleProblems(rule).map(problem => "rules[" + i + "] " + problem)));
    return found;
  }

  // Each capturing group's name, in order, null for an unnamed one: Qt's JavaScript parses named groups but never names them.
  readonly property var groupNames: pattern => {
    const names = [];
    let inClass = false;
    for (let i = 0; i < pattern.length; i++) {
      const c = pattern[i];
      if (c === "\\") i++;
      else if (inClass) inClass = c !== "]";
      else if (c === "[") inClass = true;
      else if (c === "(") {
        const named = pattern.slice(i + 1).match(/^\?<([A-Za-z_]\w*)>/);
        if (named) names.push(named[1]);
        else if (pattern[i + 1] !== "?") names.push(null);
      }
    }
    return names;
  }

  function ruleProblems(rule) {
    if (Config.kind(rule) !== "map") return ["is no object"];
    const found = Config.undeclared(rule, ruleKinds);
    if (rule.timeout < 0) found.push("sets timeout below 0");
    if ("urgency" in rule && !urgencies.includes(rule.urgency)) found.push("sets urgency to '" + rule.urgency + "', none of " + urgencies.join(", "));
    const keys = [];
    Array.from(rule.actions ?? []).forEach((action, i) => {
      const at = "actions[" + i + "] ";
      if (Config.kind(action) !== "map") return found.push(at + "is no object");
      found.push(...Config.undeclared(action, actionKinds, at));
      if (typeof action.desc !== "string" || typeof action.cmd !== "string") found.push(at + "needs a desc and a cmd");
      if (!/^[a-wyz]$/.test(action.key ?? "")) found.push(at + "sets key to '" + action.key + "': one letter, any but x, which dismisses");
      else if (keys.includes(action.key)) found.push(at + "takes key " + action.key + " twice");
      keys.push(action.key);
      const named = Object.values(rule.match ?? {}).filter(pattern => typeof pattern === "string").reduce((names, pattern) => names.concat(groupNames(pattern)), given.slice());
      const unknown = String(action.desc ?? "").match(/\{\w+\}/g)?.map(name => name.slice(1, -1)).filter(name => !named.includes(name)) ?? [];
      if (unknown.length) found.push(at + "shows " + unknown.map(name => "{" + name + "}").join(", ") + ", which no group of its match names");
    });
    for (const [field, pattern] of Object.entries(Config.kind(rule.match) === "map" ? rule.match : {})) {
      if (!fields.includes(field)) found.push("matches " + field + ", none of " + fields.join(", "));
      else if (typeof pattern !== "string") found.push("matches " + field + " with no string");
      else {
        try {
          new RegExp(pattern);
          // By case too: its commands get them upper-cased.
          const taken = groupNames(pattern).filter(name => name && given.includes(name.toLowerCase()));
          if (taken.length) found.push("matches " + field + " with a group named " + taken.join(", ") + ", which its commands already get");
        } catch (error) {
          found.push("matches " + field + " with '" + pattern + "': " + error.message);
        }
      }
    }
    return found;
  }
}
