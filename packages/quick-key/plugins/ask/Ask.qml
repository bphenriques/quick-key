pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Quick turns with an agent in a panel; its settings and line protocol are in docs/src/plugins.md.
Plugin {
  id: root

  readonly property int lines: settings.lines
  readonly property string title: settings.title || name

  // [{ prompt, image, reply, error, stopped, after, input }], the last one waiting while busy; `input` when a level's input sent it.
  property var exchanges: []
  property string session: ""
  property string draft: ""
  // An image pasted for the next prompt, as a file under $XDG_RUNTIME_DIR.
  property string image: ""
  property bool shown: false
  // Whether the prompt has the keys; it does as the panel opens, and Escape gives them back.
  property bool typing: true
  property bool unread: false
  // Whether this visit (the menu showing its input) sent it a turn, so the next send continues that conversation.
  property bool visited: false
  // What the agent waits to be allowed to run, and what it is doing.
  property string approval: ""
  property string activity: ""
  // Seconds the current run has taken, ticking only while it runs and the panel shows.
  property int sentAt: 0
  property int now: 0
  readonly property int waited: Math.max(0, now - sentAt)

  // Escape steps back without losing the conversation, as in a chat app: what needs it first, then the prompt (clear, back), then the panel.
  readonly property string escapeAction: approval ? "deny" : busy ? "stop" : !typing ? "hide" : draft || image ? "clear" : "back"
  readonly property bool canMove: !busy && exchanges.length > 0

  // Ctrl+V found no image, so it pastes text as usual.
  signal pasteText

  glyph: settings.glyph
  active: busy || unread
  tone: approval ? "warning" : ""
  views: ["AskPanel.qml"]

  function activate() {
    toggle();
  }

  function toggle() {
    if (shown) shown = false;
    else show();
  }

  function show() {
    shown = true;
    unread = false;
    typing = true;
  }

  // An input's text, answered above it while the menu shows it (the last answer staying until the next), else as a notification; one conversation per visit.
  function submit(text, background, after) {
    if (busy || request.running || !settings.ask) return false;
    if (!visited) reset();
    if (!send(text, "", after, true)) return false;
    visited = watched;
    return true;
  }

  // Whether the menu shows this turn's answer, above the input that sent it.
  function seen(exchange) {
    return !!exchange?.input && watched;
  }

  // `after` runs once the turn is answered.
  function send(prompt, image = root.image, after = "", input = false) {
    prompt = prompt.trim();
    // A stopped command may still be ending, when it traps its end.
    if ((!prompt && !image) || busy || request.running || !settings.ask) return false;
    // Asking again what failed or was stopped replaces that exchange, so the thread keeps one of each, and its `after`.
    const last = exchanges[exchanges.length - 1];
    const retried = last && last.error && last.prompt === prompt && last.image === image;
    const kept = retried ? exchanges.slice(0, -1) : exchanges;
    exchanges = kept.concat([{ prompt: prompt, image: image, reply: "", error: "", stopped: false, after: after || (retried ? last.after : ""), input: input }]);
    if (image === root.image) root.image = "";
    busy = true;
    approval = "";
    activity = "";
    sentAt = now = Math.floor(Date.now() / 1000);
    request.complaint = "";
    request.command = commandLine(settings.ask, prompt, session, image);
    request.running = true;
    return true;
  }

  function receive(line) {
    let answer;
    try {
      answer = JSON.parse(line);
    } catch (error) {
      console.warn(name + ": not JSON, ignored:", line);
      return;
    }
    // A stopped command, still ending.
    if (!busy) return;
    // Named as the turn starts, so asking again after a stop carries on in the same session.
    if (answer.session) session = answer.session;
    if (answer.approval) {
      approval = answer.approval;
      if (seen(exchanges[exchanges.length - 1])) reply = { text: "Allow " + approval + "? Answer in Ask.", tone: "warning" };
      else notify("Allow " + approval + "?");
    } else if (answer.status) {
      activity = answer.status;
    } else if (answer.reply !== undefined || answer.error !== undefined) {
      finish(answer);
    }
  }

  function finish(answer) {
    const last = Object.assign({}, exchanges[exchanges.length - 1], { reply: answer.reply ?? "", error: answer.reply ? "" : answer.error ?? "No answer", stopped: !!answer.stopped });
    exchanges = exchanges.slice(0, -1).concat([last]);
    busy = false;
    approval = "";
    if (seen(last)) reply = { text: last.error || last.reply, tone: last.error ? "alert" : "" };
    else notify(last.error || last.reply);
    if (last.reply) exec(last.after);
    if (!shown && !seen(last)) unread = true;
    if (last.error && !seen(last) && draft === "" && !image) {
      draft = last.prompt;
      image = last.image;
    }
  }

  function notify(text) {
    if (shown || !settings.notify) return;
    notifier.running = false;
    notifier.command = commandLine(settings.notify, title, text.split("\n")[0]);
    notifier.running = true;
  }

  // Ctrl+V: the clipboard's image, attached to the next prompt; without one, the text paste it would have been.
  function pasteImage() {
    if (!settings.pasteImage) return false;
    paster.path = Quickshell.env("XDG_RUNTIME_DIR") + "/" + name + "-" + Date.now();
    paster.command = commandLine(settings.pasteImage, paster.path);
    paster.running = true;
    return true;
  }

  function answerApproval(allowed) {
    if (!approval) return;
    request.write((allowed ? "allow" : "deny") + "\n");
    approval = "";
  }

  // Ends the command and puts its prompt back; a command whose run lives elsewhere traps its end to stop it there.
  function stop() {
    if (!busy) return;
    finish({ error: "Stopped", stopped: true });
    request.running = false;
  }

  // A new conversation; the unsent prompt stays, but not a failed one put back for a retry, which goes with its conversation.
  function reset() {
    stop();
    const last = exchanges[exchanges.length - 1];
    if (last?.error && draft === last.prompt && image === last.image) {
      draft = "";
      image = "";
    }
    exchanges = [];
    session = "";
    unread = false;
  }

  // Only between turns: a turn lives as long as its command here.
  function moveToTerminal() {
    if (!canMove) return;
    exec(settings.open, session);
    reset();
    shown = false;
  }

  // The panel's keys, from the keyboard or a click on the legend; whether a key was the panel's, so the rest reach the prompt. Waiting, its letters do what their Ctrl chords do.
  function act(key) {
    if (!typing && key === settings.key) {
      typing = true;
      return true;
    }
    switch (!typing && /^[a-z]$/.test(key) ? "Ctrl+" + key : key) {
    case "Escape": return stepBack();
    case "Ctrl+y": answerApproval(true); return true;
    case "Ctrl+l": reset(); return true;
    case "Ctrl+o": moveToTerminal(); return true;
    case "Ctrl+v": return pasteImage();
    }
    return false;
  }

  // Its own steps; clearing and giving the keys back are the prompt's (Prompt.stepBack), so false leaves them to it.
  function stepBack() {
    switch (escapeAction) {
    case "deny": answerApproval(false); return true;
    case "stop": stop(); return true;
    case "hide": shown = false; return true;
    }
    return false;
  }

  // The menu left the input, or closed: the visit ends, and its answer with it.
  Connections {
    target: Plugins

    function onWatchingChanged() {
      root.visited = false;
      root.reply = null;
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.busy && root.shown
    onTriggered: root.now = Math.floor(Date.now() / 1000)
  }

  Process {
    id: request
    // Its last line on stderr, the error when it ends without an answer.
    property string complaint: ""

    // Open for the approvals' answers.
    stdinEnabled: true

    stdout: SplitParser {
      onRead: line => root.receive(line)
    }

    stderr: SplitParser {
      onRead: line => {
        if (line.trim()) request.complaint = line.trim();
      }
    }

    // Ended without an answer: it crashed or was killed.
    onExited: {
      if (root.busy) root.finish({ error: complaint || "No answer" });
    }
  }

  Process {
    id: paster
    property string path

    onExited: code => {
      if (code === 0) root.image = path;
      else root.pasteText();
    }
  }

  Process {
    id: notifier

    stdout: SplitParser {
      onRead: line => {
        if (line.trim() === "default") root.show();
      }
    }
  }
}
