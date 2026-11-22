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
  words: ({
    resuming: "Resuming" + Words.ellipsis,
    newConversation: "New conversation",
    listing: "Listing conversations" + Words.ellipsis,
    none: "No conversations yet",
    noAnswer: "No answer",
    noImage: "Could not read the image",
    openTerminal: "Terminal" + Words.ellipsis,
    approval: (allowed, what) => (allowed ? "Allowed: " : "Denied: ") + what,
    allow: "allow",
    stop: "stop",
    newChat: "new",
    terminal: "terminal" + Words.ellipsis
  })
  // Its keys, each once: what `?` lists (`desc`), the legend's word while it applies (`what`, `shows`), and what one it handles runs (`run`, false when it leaves the key to the prompt).
  readonly property var keys: [
    { key: "Tab", desc: Words.helpTab },
    { key: "Shift+Return", desc: "A new line" },
    { key: "Ctrl+Shift+Return", desc: Words.helpBackground },
    { key: "Ctrl+y", desc: "Allow what it asks", what: words.allow, shows: () => approval !== "", run: () => answerApproval(true) },
    { key: "Ctrl+c", desc: "Stop the answer", what: words.stop, shows: () => busy, run: () => busy && stop() },
    { key: "y", desc: "Copy the last answer", what: Words.copy, shows: () => !typing && !!exchanges[exchanges.length - 1]?.reply, run: () => !typing && copy() },
    { key: "Ctrl+l", desc: "A new conversation", what: words.newChat, shows: () => exchanges.length > 0, run: () => reset() },
    { key: "Ctrl+o", desc: "Move it to a terminal", what: words.terminal, shows: () => canMove, run: () => moveToTerminal(), when: settings.open !== "" },
    { key: "Ctrl+r", desc: Words.helpRecall, what: Words.history, shows: () => exchanges.length === 0 && recalls, run: () => recall() },
    { key: "Ctrl+v", desc: "Attach the clipboard's image", run: () => pasteImage() },
    { key: "1-9", desc: "Pick an option" },
    { key: "Escape", desc: Words.helpEscape }
  ].filter(entry => entry.when !== false)

  // [{ prompt, image, reply, error, stopped, after, input, options, table, steps }], the last one streaming in while busy; `input` when a level's input sent it, or its panel while expanded from one.
  property var exchanges: []
  // The conversation, as the agent knows it (Acp).
  property alias session: agent.session
  property string draft: ""
  // An image pasted for the next prompt, as a file under $XDG_RUNTIME_DIR.
  property string image: ""
  // On top of Panels.
  readonly property bool shown: Panels.top === root
  // Whether the prompt has the keys; it does as the panel opens, and Tab moves them.
  property bool typing: true
  property bool unread: false
  // Whether this visit (the menu showing its input) sent it a turn, so the next send continues that conversation.
  property bool visited: false
  // `?` with the prompt dim: the panel's keys in place of the conversation, until the next key.
  property bool helping: false
  // What a digit picks: the last answer's options, once it is in.
  readonly property var choices: busy ? [] : exchanges[exchanges.length - 1]?.options ?? []
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
  readonly property bool canMove: !busy && exchanges.length > 0 && settings.open !== ""

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
    actions: settings.open ? [{ key: "o", desc: words.openTerminal, closes: true }] : []
  }))
  empty: listing ? words.listing : words.none

  // Its past conversations, listed afresh each time, in the picker.
  function recall() {
    if (!settings.ask) return false;
    listing = true;
    failure = "";
    agent.list((sessions, why) => {
      listing = false;
      conversations = sessions ?? [];
      failure = why;
    });
    Picker.pick(name);
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
    if (shown) Panels.close();
    else show();
  }

  function show() {
    Panels.open(root);
    unread = false;
    typing = true;
  }

  // The whole conversation, over the menu, for what the answer over an input cannot fit (Plugin.expand).
  function expand() {
    show();
    return true;
  }

  // An option of the last answer, sent as the next message.
  function pick(index) {
    const option = choices[index];
    if (option === undefined) return false;
    return send(option, "");
  }

  onShownChanged: helping = false

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
    exchanges = kept.concat([{ prompt: prompt, image: image, reply: "", error: "", stopped: false, after: after || (retried ? last.after : ""), input: input || watched }]);
    if (image === root.image) root.image = "";
    busy = true;
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

  // The last exchange with `fields` changed, the list replaced so what draws it hears; that exchange as it is now.
  function setLast(fields) {
    const last = Object.assign({}, exchanges[exchanges.length - 1], fields);
    exchanges = exchanges.slice(0, -1).concat([last]);
    return last;
  }

  function flush() {
    if (!streamed) return;
    setLast({ reply: exchanges[exchanges.length - 1].reply + streamed });
    streamed = "";
    report();
  }

  function fail(message) {
    finish({ error: message });
  }

  function finish(answer) {
    const last = setLast({ reply: answer.reply ?? "", error: answer.reply ? "" : answer.error ?? words.noAnswer, stopped: !!answer.stopped, options: answer.reply ? answer.options ?? [] : [], table: !!answer.table });
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
    call(settings.encodeImage, [path], (code, output) => code === 0 ? then(output.trim()) : fail(words.noImage));
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
    const path = Quickshell.env("XDG_RUNTIME_DIR") + "/" + name + "-" + Date.now();
    call(settings.pasteImage, [path], code => code === 0 ? root.image = path : root.pasteText());
    return true;
  }

  // Allow or deny once; an agent offering neither for the answer is told it was cancelled.
  function answerApproval(allowed) {
    if (!approval) return;
    agent.answer(allowed);
    setLast({ steps: (exchanges[exchanges.length - 1].steps ?? []).concat([words.approval(allowed, approval)]) });
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
    Panels.close();
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
    if (key === "Escape") return stepBack();
    const entry = keys.find(entry => entry.run && (entry.key === key || typedAs(entry.key) === key));
    return !!entry && entry.run() !== false;
  }

  // The key that runs one of its keys now: waiting, a chord's letter alone, but `C-y`'s, as a bare `y` copies: a key learned as harmless never approves.
  function typedAs(key) {
    return !typing && /^Ctrl\+[a-z]$/.test(key) && key !== "Ctrl+y" ? key.slice(5) : key;
  }

  // With the prompt dim, Escape leaves, the conversation kept; typing, clearing first is the prompt's (Prompt.stepBack), so false leaves it to it.
  function stepBack() {
    if (typing) return false;
    Panels.back();
    return true;
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
      if (root.settings.toolPattern && root.settings.toolPattern.test(title)) root.touched = true;
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
    id: notifier

    stdout: SplitParser {
      onRead: line => {
        if (line.trim() === "default") root.show();
      }
    }
  }
}
