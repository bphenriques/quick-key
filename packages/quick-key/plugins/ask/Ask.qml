pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Quick turns with an ACP agent in a panel, the agent kept running between turns; its settings are in docs/src/plugins.md.
Plugin {
  id: root

  readonly property int lines: settings.lines
  readonly property string title: settings.title || name

  // [{ prompt, image, reply, error, stopped, after, input, options, table, steps }], the last one streaming in while busy; `input` when a level's input sent it, or its panel while expanded from one.
  property var exchanges: []
  // The conversation, as the agent knows it (Acp).
  property alias session: agent.session
  property string draft: ""
  // An image pasted for the next prompt, as a file under $XDG_RUNTIME_DIR.
  property string image: ""
  property bool shown: false
  // Whether the prompt has the keys; it does as the panel opens, and Escape gives them back.
  property bool typing: true
  property bool unread: false
  // Whether this visit (the menu showing its input) sent it a turn, so the next send continues that conversation.
  property bool visited: false
  // How its panel was opened from an input's answer, to say how it is left (Plugin.expand); null otherwise.
  property var backTo: null
  // Escape set the last answer's options aside: digits type again.
  property bool aside: false
  // `?` with the prompt dim: the panel's keys in place of the conversation, until the next key.
  property bool helping: false
  // What a digit picks: the last answer's options, once it is in.
  readonly property var choices: busy || aside ? [] : exchanges[exchanges.length - 1]?.options ?? []
  // What the agent waits to be allowed to run, and what it is doing.
  property string approval: ""
  property string activity: ""
  // A tool `toolMatch` names ran this turn.
  property bool touched: false
  // The answer's pieces since the last flush: applied at most every 50 ms, so a fast stream costs a few redraws a second, not one a piece.
  property string streamed: ""
  // Its past conversations as the agent lists them ([{ sessionId, title, updatedAt }]), while it lists them, and why it could not.
  property var conversations: []
  property bool listing: false
  property string failure: ""
  // A conversation being resumed, and its history as the agent replays it, built in place and shown once whole.
  property bool resuming: false
  property var recalled: []
  // Seconds the current run has taken, ticking only while it runs and the panel shows.
  property int sentAt: 0
  property int now: 0
  readonly property int waited: Math.max(0, now - sentAt)
  // Escape steps back without losing the conversation, as in a chat app: what needs it first, then the prompt (clear, back), then the panel.
  readonly property string escapeAction: approval ? "deny" : busy ? "stop" : choices.length > 0 && !draft && !image ? "type" : !typing ? (backTo ? "menu" : "hide") : draft || image ? "clear" : "back"
  readonly property bool canMove: !busy && exchanges.length > 0

  // Ctrl+V found no image, so it pastes text as usual.
  signal pasteText

  // Its status shows only while it has something to report: a run, an answer unread, a question for you.
  glyph: busy || unread || approval ? settings.glyph : ""
  active: busy || unread
  tone: approval ? "warning" : ""
  error: failure
  views: ["AskPanel.qml"]
  recalls: settings.ask !== ""
  // The open one lit; one the agent cannot carry on dims.
  items: conversations.map(conversation => ({
    id: conversation.sessionId,
    label: conversation.title || conversation.sessionId,
    icon: Glyphs.conversation,
    detail: conversation.updatedAt ? Clock.recent(new Date(conversation.updatedAt)) : "",
    active: conversation.sessionId === session,
    enabled: agent.canLoad,
    verb: "resume",
    actions: settings.open ? [{ key: "o", desc: "Terminal" + Words.ellipsis, closes: true }] : []
  }))
  empty: listing ? "Listing conversations" + Words.ellipsis : "No conversations yet"

  // Its past conversations, listed afresh each time, in the picker.
  function recall(back) {
    if (!settings.ask) return false;
    listing = true;
    failure = "";
    agent.list((sessions, why) => {
      listing = false;
      conversations = sessions ?? [];
      failure = why;
    });
    Picker.pick(name, back);
    return true;
  }

  function select(id) {
    resume(id);
  }

  function run(id, key) {
    if (key === "o") exec(settings.open, id);
  }

  // An earlier conversation in the panel, between turns: the one open just shows, another loads, its history replayed (Acp.load).
  function resume(id) {
    if (busy) return;
    if (id !== session || exchanges.length === 0) {
      reset();
      recalled = [];
      resuming = true;
      busy = true;
      agent.load(id);
    }
    show();
  }

  // The history replayed, as exchanges, the last one's options waiting as a fresh answer's do; stopped or failed, none.
  function resumed(outcome) {
    resuming = false;
    busy = false;
    failure = outcome.error ?? "";
    exchanges = !outcome.loaded ? [] : recalled.map(entry => {
      const shaped = Markup.options(entry.reply);
      return { prompt: entry.prompt.trim(), image: "", reply: shaped.text, error: "", stopped: false, after: "", input: false, options: shaped.options, table: Markup.hasTable(entry.reply) };
    });
    recalled = [];
  }

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

  // The whole conversation, for what the answer over an input cannot fit (Plugin.expand).
  function expand(back) {
    backTo = back;
    show();
    return true;
  }

  // Hidden, saying so to the menu that expanded it: `returning` when stepped back from.
  function leave(returning) {
    const back = backTo;
    backTo = null;
    shown = false;
    if (back) back(returning);
  }

  // An option of the last answer, sent as the next message.
  function pick(index) {
    const option = choices[index];
    if (option === undefined) return false;
    return send(option, "");
  }

  // Left any other way (sent in the background, dismissed, a link opened): not back to the menu.
  onShownChanged: {
    helping = false;
    if (!shown && backTo) leave(false);
  }

  // An input's text, answered above it while the menu shows it (the last answer staying until the next), else as a notification; one conversation per visit.
  function submit(text, background, after) {
    if (busy || !settings.ask) return false;
    if (!visited) reset();
    if (!send(text, "", after, true)) return false;
    visited = watched;
    return true;
  }

  // Whether the menu shows this turn's answer, above the input that sent it.
  function seen(exchange) {
    return !!exchange?.input && watched;
  }

  // An answer with the options it gave, on one line: what a reply to it answers.
  function followed(exchange) {
    return exchange ? [exchange.reply, (exchange.options ?? []).join(" · ")].filter(part => part).join(" ") : "";
  }

  // An exchange by its phase, as an Exchange draws it: the last one working, or waiting on you, while busy, and choosing while its options wait.
  function describe(exchange) {
    const latest = exchange === exchanges[exchanges.length - 1];
    const phase = latest && busy ? (approval ? "waiting" : "working")
      : exchange.stopped ? "stopped" : exchange.error ? "failed" : latest && choices.length > 0 ? "choosing" : "answered";
    return {
      question: exchange.prompt,
      image: exchange.image,
      text: phase === "waiting" ? Words.allowQuestion(approval) : exchange.error || exchange.reply,
      phase: phase,
      activity: phase === "working" ? activity : "",
      // While it works, the answer it follows with the options it gave, so the question shows what it answers.
      context: phase === "working" ? followed(exchanges[exchanges.indexOf(exchange) - 1]) : "",
      options: phase === "choosing" ? choices : [],
      table: !!exchange.table,
      steps: exchange.steps ?? []
    };
  }

  // The last exchange, for the menu, when it shows it (Plugin.turn).
  function report() {
    const last = exchanges[exchanges.length - 1];
    if (seen(last)) turn = describe(last);
  }

  // `after` runs once the turn is answered.
  function send(prompt, image = root.image, after = "", input = false) {
    prompt = prompt.trim();
    if ((!prompt && !image) || busy || !settings.ask) return false;
    // Asking again what failed or was stopped replaces that exchange, so the thread keeps one of each, and its `after`.
    const last = exchanges[exchanges.length - 1];
    const retried = last && last.error && last.prompt === prompt && last.image === image;
    const kept = retried ? exchanges.slice(0, -1) : exchanges;
    exchanges = kept.concat([{ prompt: prompt, image: image, reply: "", error: "", stopped: false, after: after || (retried ? last.after : ""), input: input || backTo !== null }]);
    if (image === root.image) root.image = "";
    busy = true;
    aside = false;
    approval = "";
    activity = "";
    touched = false;
    streamed = "";
    sentAt = now = Math.floor(Date.now() / 1000);
    report();
    if (image) encode(image, data => agent.turn([{ type: "text", text: prompt }, { type: "image", data: data, mimeType: mimeOf(data) }].filter(block => block.type !== "text" || block.text)));
    else agent.turn([{ type: "text", text: prompt }]);
    return true;
  }

  // The turn's end, as the agent reports it: the answer it streamed, with its options and table, else why not.
  function close(outcome) {
    if (resuming) return resumed(outcome);
    flush();
    if (!outcome.answered) return finish({ error: outcome.error ?? "Stopped", stopped: !!outcome.stopped });
    const text = exchanges[exchanges.length - 1].reply;
    const shaped = Markup.options(text);
    finish({ reply: shaped.text, options: shaped.options, table: Markup.hasTable(text) });
  }

  function flush() {
    if (!streamed) return;
    const last = exchanges[exchanges.length - 1];
    exchanges = exchanges.slice(0, -1).concat([Object.assign({}, last, { reply: last.reply + streamed })]);
    streamed = "";
    report();
  }

  function fail(message) {
    finish({ error: message });
  }

  function finish(answer) {
    const last = Object.assign({}, exchanges[exchanges.length - 1], { reply: answer.reply ?? "", error: answer.reply ? "" : answer.error ?? "No answer", stopped: !!answer.stopped, options: answer.reply ? answer.options ?? [] : [], table: !!answer.table });
    exchanges = exchanges.slice(0, -1).concat([last]);
    busy = false;
    approval = "";
    if (seen(last)) report();
    else notify(last.error || [last.reply].concat(last.options).join(" · "));
    if (last.reply) exec(last.after);
    if (touched) exec(settings.toolRun);
    if (!shown && !seen(last)) unread = true;
    if (last.error && !seen(last) && draft === "" && !image) {
      draft = last.prompt;
      image = last.image;
    }
  }

  // An image as the agent takes it: base64, its type read from its first bytes.
  function encode(path, then) {
    encoder.done = then;
    encoder.command = commandLine(settings.encodeImage, path);
    encoder.running = true;
  }

  function mimeOf(data) {
    return data.startsWith("/9j/") ? "image/jpeg" : data.startsWith("R0lGOD") ? "image/gif" : data.startsWith("UklGR") ? "image/webp" : "image/png";
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

  // Allow or deny once; an agent offering neither for the answer is told it was cancelled.
  function answerApproval(allowed) {
    if (!approval) return;
    agent.answer(allowed);
    const last = exchanges[exchanges.length - 1];
    exchanges = exchanges.slice(0, -1).concat([Object.assign({}, last, { steps: (last.steps ?? []).concat([(allowed ? "Allowed: " : "Denied: ") + approval]) })]);
    approval = "";
  }

  // The last answer, to the clipboard.
  function copy() {
    const reply = exchanges[exchanges.length - 1]?.reply ?? "";
    if (!reply) return false;
    Quickshell.clipboardText = reply;
    return true;
  }

  // Cancels the turn and puts its prompt back; the agent stays for the next one (Acp.cancel).
  function stop() {
    if (busy) agent.cancel();
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

  // Only between turns, so the terminal takes a settled conversation.
  function moveToTerminal() {
    if (!canMove) return;
    exec(settings.open, session);
    reset();
    shown = false;
  }

  // The panel's keys, from the keyboard or a click on the legend; whether a key was the panel's, so the rest reach the prompt. Waiting, `?` lists them (any key closing the list) and its letters do what their Ctrl chords do, but for `y`.
  function act(key) {
    if (helping) {
      helping = false;
      return true;
    }
    if (!typing && key === "?") {
      helping = true;
      return true;
    }
    // Tab moves the keys between the prompt and the panel, as in a level; Shift+Tab back to the panel, and from the panel it is Qt's.
    if (key === "Tab" || (typing && key === "Backtab")) {
      typing = !typing;
      return true;
    }
    // A waiting choice takes the digits while the prompt is empty, a digit picking and never typing.
    if (/^[1-9]$/.test(key) && !draft && !image && Number(key) <= choices.length) return pick(Number(key) - 1);
    // A bare `y` copies the last answer, as in the menu, and never allows: allowing takes its chord, so a key learned as harmless never approves.
    if (!typing && key === "y") return copy();
    switch (!typing && /^[a-z]$/.test(key) ? "Ctrl+" + key : key) {
    case "Escape": return stepBack();
    case "Ctrl+y": answerApproval(true); return true;
    case "Ctrl+l": reset(); return true;
    case "Ctrl+o": moveToTerminal(); return true;
    case "Ctrl+r": return recall(() => show());
    case "Ctrl+v": return pasteImage();
    }
    return false;
  }

  // Its own steps; clearing and giving the keys back are the prompt's (Prompt.stepBack), so false leaves them to it.
  function stepBack() {
    switch (escapeAction) {
    case "deny": answerApproval(false); return true;
    case "stop": stop(); return true;
    case "type": aside = true; return true;
    case "menu":
    case "hide": leave(true); return true;
    }
    return false;
  }

  // The menu left the input, or closed: the visit ends, and its answer with it.
  Connections {
    target: Plugins

    function onWatchingChanged() {
      root.visited = false;
      root.turn = null;
    }
  }

  Timer {
    interval: 1000
    repeat: true
    running: root.busy && root.shown
    onTriggered: root.now = Math.floor(Date.now() / 1000)
  }

  Acp {
    id: agent
    command: root.commandLine(root.settings.ask)
    name: root.title
    cwd: root.settings.cwd || Quickshell.env("HOME")
    idle: root.settings.idle
    onText: chunk => {
      root.streamed += chunk;
      if (!flushing.running) flushing.start();
    }
    onTool: title => {
      // An MCP tool by its server (mcp__meals__plan_week: meals), the rest by name.
      root.activity = title.startsWith("mcp__") ? title.split("__")[1] : title;
      if (root.settings.toolMatch && new RegExp(root.settings.toolMatch).test(title)) root.touched = true;
      root.report();
    }
    onRestarted: {
      root.activity = Words.restarted;
      root.report();
    }
    onPermission: title => {
      root.approval = title;
      if (root.seen(root.exchanges[root.exchanges.length - 1])) root.report();
      else root.notify(Words.allowQuestion(title));
    }
    onHistory: (role, chunk) => {
      const last = root.recalled[root.recalled.length - 1];
      if (role === "user" && (!last || last.reply)) root.recalled.push({ prompt: chunk, reply: "" });
      else if (role === "user") last.prompt += chunk;
      else if (last) last.reply += chunk;
      else root.recalled.push({ prompt: "", reply: chunk });
    }
    onEnded: outcome => root.close(outcome)
  }

  Timer {
    id: flushing
    interval: 50
    onTriggered: root.flush()
  }

  Process {
    id: encoder
    property var done

    stdout: StdioCollector {
      id: encoded
    }

    onExited: code => code === 0 ? done(encoded.text.trim()) : root.fail("Could not read the image")
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
