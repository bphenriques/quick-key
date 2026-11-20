pragma Singleton

import QtQuick
import Quickshell
import qs

// The words the surfaces share, one per meaning, so a state or a key is never named two ways (AGENTS.md rules 6 and 7).
Singleton {
  // The one ellipsis: what opens a picker or an app, what is under way, what waits on you.
  readonly property string ellipsis: "..."

  // A conversation's phases, as its answer and the prompt under it say them.
  readonly property string thinking: "Thinking"
  readonly property string replyPrompt: "Reply" + ellipsis
  readonly property string pickPrompt: "A digit picks, or reply" + ellipsis
  readonly property string approvePrompt: MenuKeys.label("Ctrl+y") + " allows, " + MenuKeys.label("Ctrl+c") + " stops" + ellipsis
  readonly property string syncing: "syncing" + ellipsis
  // An agent that could not carry on the conversation, starting a new one.
  readonly property string restarted: "Started a new conversation"
  // A picker's filter, empty and when it leaves nothing.
  readonly property string filterPrompt: "Filter" + ellipsis

  // What Return does after a turn in `phase`, for the prompt under it: nothing while it works, where the answer says so and typing ahead is free.
  function next(phase, picking, options) {
    return phase === "working" ? "" : phase === "waiting" ? approvePrompt : picking && options > 0 ? pickPrompt : replyPrompt;
  }

  // A list's rows at rest of all it holds, when it holds more (1-9 of 14).
  function shownOf(total) {
    return "1-9 of " + total;
  }

  function noMatch(text) {
    return "Nothing matches " + text;
  }

  // What an agent waits to be allowed to do, asked.
  function allowQuestion(what) {
    return "Allow " + what + "?";
  }

  // What a key does, in a legend: a lowercase word or two.
  readonly property string allow: "allow"
  readonly property string appMenu: "app menu"
  readonly property string choose: "choose"
  readonly property string clear: "clear"
  readonly property string copy: "copy"
  readonly property string day: "day"
  readonly property string event: "event"
  readonly property string events: "events"
  readonly property string help: "keys"
  readonly property string history: "history"
  readonly property string menu: "menu"
  readonly property string month: "month"
  readonly property string move: "move"
  readonly property string newChat: "new"
  readonly property string open: "open"
  readonly property string pick: "pick"
  readonly property string stop: "stop"
  readonly property string terminal: "terminal" + ellipsis
  readonly property string today: "today"
  readonly property string week: "week"
  readonly property string year: "year"
}
