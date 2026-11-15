pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.ui

// Quick turns with an agent in a panel; its settings and line protocol are in docs/src/plugins.md.
Plugin {
  id: root

  // In lines, like the menu's width in pixels: declared, so the panel holds still (rule 4).
  readonly property int lines: 14
  readonly property string title: settings.title ?? name

  // [{ prompt, image, reply, error, stopped }], the last one waiting while busy.
  property var exchanges: []
  property string session: ""
  property string draft: ""
  // An image pasted for the next prompt, as a file under $XDG_RUNTIME_DIR.
  property string image: ""
  property bool shown: false
  property bool busy: false
  property bool unread: false
  // Bumped when a conversation ends, so output for an ended one is dropped.
  property int conversation: 0
  // The current run as the agent names it, what it waits to be allowed to run, and what it is doing.
  property string run: ""
  property string approval: ""
  property string activity: ""
  // Seconds the current run has taken, ticking only while it runs and the panel shows.
  property int sentAt: 0
  property int now: 0
  readonly property int waited: Math.max(0, now - sentAt)

  // Escape steps back without losing the conversation, as in a chat app; twice quickly hides.
  readonly property string escapeAction: approval ? "deny" : busy ? "stop" : draft || image ? "clear" : "hide"
  readonly property bool canMove: !busy && exchanges.length > 0
  property real lastEscape: 0

  // For the prompt, which lives in the panel's window: put a failed prompt back (Return retries it), or clear it.
  signal restore(string prompt)
  signal clearPrompt
  // Ctrl+V found no image, so it pastes text as usual.
  signal pasteText

  glyph: settings.glyph ?? ""
  active: busy || unread
  tone: approval ? "warning" : ""

  function activate() {
    toggle();
  }

  function toggle() {
    shown = !shown;
    if (shown) unread = false;
  }

  function send(prompt) {
    prompt = prompt.trim();
    if ((!prompt && !image) || busy || request.stopping || !settings.ask) return false;
    // Asking again what failed or was stopped replaces that exchange, so the thread keeps one of each.
    const last = exchanges[exchanges.length - 1];
    const kept = last && last.error && last.prompt === prompt && last.image === image ? exchanges.slice(0, -1) : exchanges;
    exchanges = kept.concat([{ prompt: prompt, image: image, reply: "", error: "", stopped: false }]);
    const sent = image;
    image = "";
    busy = true;
    run = "";
    approval = "";
    activity = "";
    sentAt = now = Math.floor(Date.now() / 1000);
    request.conversation = conversation;
    request.complaint = "";
    request.command = commandLine(settings.ask, prompt, session, sent);
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
    // Stopped before it said its name: closing the stream does not stop a run, so stop it now that it has one.
    if (request.stopping) {
      if (answer.run) {
        exec(settings.stop, answer.run);
        request.stopping = false;
        request.running = false;
      }
      return;
    }
    if (request.conversation !== conversation || !busy) return;
    if (answer.run) {
      run = answer.run;
      // Known from the start, so asking again after a stop carries on in the same session.
      session = answer.session ?? session;
    } else if (answer.approval) {
      approval = answer.approval;
      notify("Allow " + approval + "?");
    } else if (answer.status) {
      activity = answer.status;
    } else {
      finish(answer);
    }
  }

  function finish(answer) {
    if (answer.session) session = answer.session;
    const last = Object.assign({}, exchanges[exchanges.length - 1], { reply: answer.reply ?? "", error: answer.reply ? "" : answer.error ?? "No answer", stopped: !!answer.stopped });
    exchanges = exchanges.slice(0, -1).concat([last]);
    busy = false;
    approval = "";
    notify(last.error || last.reply);
    if (!shown) unread = true;
    if (last.error && draft === "" && !image) {
      draft = last.prompt;
      image = last.image;
      restore(last.prompt);
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
    if (!approval || !settings.approve) return;
    exec(settings.approve, run, allowed ? "allow" : "deny");
    approval = "";
  }

  // Stops the run where it runs and puts its prompt back; one not yet named is stopped once it is (receive).
  function stop() {
    if (!busy) return;
    finish({ error: "Stopped", stopped: true });
    if (!settings.stop) {
      request.running = false;
    } else if (run) {
      exec(settings.stop, run);
      request.running = false;
    } else {
      request.stopping = true;
    }
  }

  // A new conversation; the unsent prompt stays.
  function reset() {
    stop();
    conversation++;
    exchanges = [];
    session = "";
    unread = false;
  }

  // Only between runs: a run lives as long as its stream here.
  function moveToTerminal() {
    if (!canMove) return;
    exec(settings.open, session);
    reset();
    shown = false;
  }

  // The panel's keys, from the keyboard or a click on the legend; whether a key was the panel's, so the rest reach the prompt.
  function act(key) {
    switch (key) {
    case "Escape": stepBack(); return true;
    case "Ctrl+y": answerApproval(true); return true;
    case "Ctrl+l": reset(); return true;
    case "Ctrl+o": moveToTerminal(); return true;
    case "Ctrl+v": return pasteImage();
    }
    return false;
  }

  function stepBack() {
    const twice = Date.now() - lastEscape < 400;
    lastEscape = Date.now();
    if (twice) {
      shown = false;
      return;
    }
    switch (escapeAction) {
    case "deny": answerApproval(false); break;
    case "stop": stop(); break;
    case "clear":
      clearPrompt();
      image = "";
      break;
    default: shown = false;
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
    property int conversation: 0
    // Stopped before its run had a name: kept open until it has one.
    property bool stopping: false
    // Its last line on stderr, the error when it ends without an answer.
    property string complaint: ""

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
      stopping = false;
      if (root.busy && conversation === root.conversation) root.finish({ error: complaint || "No answer" });
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
        if (line.trim() !== "default") return;
        root.shown = true;
        root.unread = false;
      }
    }
  }

  // Created by path while shown: a plugin's folder is not a module the shell imports.
  property var panel: null
  onShownChanged: {
    if (!shown) {
      panel?.destroy();
      panel = null;
      return;
    }
    const component = Qt.createComponent(Qt.resolvedUrl("ask/AskPanel.qml"));
    panel = component.createObject(root, { ask: root });
    if (!panel) console.warn(name + ":", component.errorString());
  }
}
