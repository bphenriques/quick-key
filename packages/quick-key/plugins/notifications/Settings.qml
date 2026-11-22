import QtQuick
import qs

// The notifications' settings (docs/src/plugins.md#notifications); `owner` the one tool it names, the standard busctl.
PluginSettings {
  // The corner the cards stack in.
  property string corner: "top-right"
  // Cards shown at once; the rest wait, counted.
  property int limit: 3
  // Seconds a card shows, by urgency, when its sender sets none; a critical one stays until dismissed.
  property var timeout: ({ low: 3, normal: 8 })
  // The side of a card its actions sit on.
  property string actionSide: "right"
  // Its cards' width, in pixels.
  property int width: 480
  // Its compositor key (`shortcut`) dimly by the cards at rest, teaching it.
  property bool hint: false
  // Each { match, hide, timeout, urgency, ignorePause, actions, default, run }, in order, later ones winning but actions adding up; `match` maps fields to regular expressions, every one found for the rule to apply, its named groups (`(?<code>\d+)`) values for its commands and labels.
  property var rules: []
  // Prints the process id holding the notifications' name on the session bus, last on its line: another daemon there shows as its error.
  property string owner: "busctl --user call org.freedesktop.DBus /org/freedesktop/DBus org.freedesktop.DBus GetConnectionUnixProcessID s org.freedesktop.Notifications"

  readonly property var corners: ["top-right", "top-left", "bottom-right", "bottom-left"]
  readonly property var sides: ["right", "left"]
  readonly property var fields: ["app", "summary", "body", "category", "urgency", "desktopEntry"]
  readonly property var ruleKeys: ["match", "hide", "timeout", "urgency", "ignorePause", "actions", "default", "run"]
  readonly property var actionKeys: ["key", "desc", "icon", "cmd"]
  // What its commands get as NOTIFICATION_<NAME>, so a group by one of these names would hide it.
  readonly property var given: ["app", "summary", "body", "urgency", "id"]
  readonly property var urgencies: ["low", "normal", "critical"]

  function problems() {
    const found = [];
    if (!corners.includes(corner)) found.push("sets corner to '" + corner + "', none of " + corners.join(", "));
    if (!sides.includes(actionSide)) found.push("sets actionSide to '" + actionSide + "', none of " + sides.join(", "));
    if (limit < 1) found.push("sets limit below 1");
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
    if (rule === null || typeof rule !== "object" || Array.isArray(rule)) return ["is no object"];
    const found = Object.keys(rule).filter(key => !ruleKeys.includes(key)).map(key => "sets " + key + ", none of " + ruleKeys.join(", "));
    if ("hide" in rule && typeof rule.hide !== "boolean") found.push("sets hide to no boolean");
    if ("ignorePause" in rule && typeof rule.ignorePause !== "boolean") found.push("sets ignorePause to no boolean");
    if ("timeout" in rule && (typeof rule.timeout !== "number" || rule.timeout < 0)) found.push("sets timeout to no number of seconds");
    if ("urgency" in rule && !urgencies.includes(rule.urgency)) found.push("sets urgency to '" + rule.urgency + "', none of " + urgencies.join(", "));
    for (const key of ["default", "run"]) {
      if (key in rule && typeof rule[key] !== "string") found.push("sets " + key + " to no command");
    }
    const keys = [];
    Array.from(rule.actions ?? []).forEach((action, i) => {
      const at = "actions[" + i + "] ";
      if (action === null || typeof action !== "object") return found.push(at + "is no object");
      found.push(...Object.keys(action).filter(key => !actionKeys.includes(key)).map(key => at + "sets " + key + ", none of " + actionKeys.join(", ")));
      if (typeof action.desc !== "string" || typeof action.cmd !== "string") found.push(at + "needs a desc and a cmd");
      if (!/^[a-wyz]$/.test(action.key ?? "")) found.push(at + "sets key to '" + action.key + "': one letter, any but x, which dismisses");
      else if (keys.includes(action.key)) found.push(at + "takes key " + action.key + " twice");
      keys.push(action.key);
    });
    for (const [field, pattern] of Object.entries(rule.match ?? {})) {
      if (!fields.includes(field)) found.push("matches " + field + ", none of " + fields.join(", "));
      else if (typeof pattern !== "string") found.push("matches " + field + " with no string");
      else {
        try {
          new RegExp(pattern);
          const taken = groupNames(pattern).filter(name => given.includes(name));
          if (taken.length) found.push("matches " + field + " with a group named " + taken.join(", ") + ", which its commands already get");
        } catch (error) {
          found.push("matches " + field + " with '" + pattern + "': " + error.message);
        }
      }
    }
    return found;
  }
}
