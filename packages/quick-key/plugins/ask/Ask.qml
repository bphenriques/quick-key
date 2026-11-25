pragma ComponentBehavior: Bound

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.ui
import qs.ui.conversation
import "exchanges.js" as Exchanges

// An ACP agent in a panel, kept running between turns (docs/src/plugins.md).
Plugin {
  id: root

  words: ({
    resuming: "Resuming" + Words.ellipsis,
    listing: "Listing conversations" + Words.ellipsis,
    none: "No conversations yet",
    noAnswer: "No answer",
    openTerminal: "Terminal" + Words.ellipsis,
    approval: (allowed, what) => (allowed ? "Allowed: " : "Denied: ") + what,
    notOnce: what => "Cancelled, not offered once: " + what,
    allow: "allow",
    deny: "deny",
    allowQuestion: what => "Allow " + what + "?",
    // An agent that could not carry on the conversation, starting a new one.
    restarted: "Started a new conversation",
    stop: "stop",
    newChat: "new",
    terminal: "terminal" + Words.ellipsis,
    helpBreak: "Break the line",
    helpScrollUp: "Scroll up",
    helpScrollDown: "Scroll down"
  })
  // Each key once, `what` and `shows` for the legend, which leaves out a `hidden` one; it runs only while it shows, `run` returning false to leave it to the prompt.
  readonly property var keys: [
    { key: "Ctrl+y", what: words.allow, shows: () => approval !== "", run: () => answerApproval(true) },
    { key: "Ctrl+n", what: words.deny, shows: () => approval !== "", run: () => answerApproval(false) },
    { key: "Ctrl+c", what: words.stop, shows: () => busy, run: () => stop() },
    // Shift with C-c, as terminals copy.
    { key: "Ctrl+C", what: Words.copy, shows: () => !busy && !!exchanges[exchanges.length - 1]?.reply, run: () => copy() },
    { key: "Ctrl+l", what: words.newChat, shows: () => exchanges.length > 0, run: () => reset() },
    { key: "Ctrl+o", what: words.terminal, shows: () => canMove, run: () => moveToTerminal(), when: settings.open !== "" },
    { key: "Ctrl+r", what: Words.history, shows: () => recalls, run: () => recall() },
    // `?` with Ctrl, as the prompt has the keys throughout.
    { key: "Ctrl+?", what: Words.help, shows: () => true, hidden: !Config.menu.keysHint, run: () => helping = true }
  ].filter(entry => entry.when !== false)
  // The keys the bar leaves out, listed in the conversation's place while `helping`; any key closes them.
  readonly property var help: [
    { key: "Shift+Return", desc: words.helpBreak },
    { key: "Page_Up", desc: words.helpScrollUp },
    { key: "Page_Down", desc: words.helpScrollDown },
    { key: "Ctrl+Shift+Return", desc: Words.helpSendLeave },
    { key: "Escape", desc: Words.helpEscape }
  ]
  property bool helping: false

  // [{ prompt, reply, error, stopped, after, input, table, steps }], the last streaming while busy; `input` when a level input sent it.
  property var exchanges: []
  property alias session: agent.session
  property string draft: ""
  readonly property bool shown: Panels.top === root
  onShownChanged: helping = false
  property bool unread: false
  // "working" on a turn (send), "resuming" a conversation it replays (resume), else "idle", as the agent's end sets it (close).
  property string stage: "idle"
  // This visit sent it a turn, so the next send continues that conversation.
  property bool visited: false
  property string approval: ""
  property string activity: ""
  // A tool `toolMatch` matches ran this turn.
  property bool touched: false
  // Applied at most every 50 ms, so a fast stream redraws a few times a second.
  property string streamed: ""
  // [{ sessionId, title, updatedAt }], as the agent lists them.
  property var conversations: []
  property bool listing: false
  property string failure: ""
  // The history the agent replays, built in place and shown once whole.
  property var recalled: []
  // Seconds the run has taken, ticking only while it runs and shows.
  property int sentAt: 0
  property int now: 0
  readonly property int waited: Math.max(0, now - sentAt)
  readonly property bool canMove: !busy && exchanges.length > 0 && settings.open !== ""

  phase: stage !== "idle" ? (approval ? "blocked" : "working") : unread ? (exchanges[exchanges.length - 1]?.error ? "error" : "done") : "idle"
  glyph: phase !== "idle" ? settings.glyph : ""
  error: failure
  views: ["AskPanel.qml"]
  // Assumed until the agent has said, at its start, that it keeps no list.
  recalls: settings.ask !== "" && !busy && (!agent.started || agent.canList)
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

  function recall() {
    if (!recalls) return false;
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

  function run(id, key) {
    if (key === "o") exec(settings.open, id);
  }

  // The one open just shows; another loads, its history replayed (Acp.load).
  function select(id) {
    if (busy) return;
    if (id !== session || exchanges.length === 0) {
      reset();
      recalled = [];
      stage = "resuming";
      agent.load(id);
    }
    show();
  }

  function resumed(outcome) {
    stage = "idle";
    failure = outcome.error ?? "";
    if (!outcome.loaded) session = "";
    exchanges = !outcome.loaded ? [] : recalled.map(entry => {
      return { prompt: Exchanges.typed(entry.prompt), reply: entry.reply, error: "", stopped: false, after: "", input: false, table: Markup.hasTable(entry.reply) };
    });
    recalled = [];
  }

  function activate() {
    if (shown) Panels.close();
    else show();
  }

  function show() {
    Panels.open(root);
    unread = false;
  }

  // For what the answer over an input cannot fit (Plugin.expand).
  function expand() {
    show();
    return true;
  }

  // Answered above the input while the menu shows it, else as a notification; one conversation per visit.
  function submit(text, after, context) {
    if (busy || !settings.ask) return false;
    if (!visited) reset();
    if (!send(text, after, true, context)) return false;
    visited = watched;
    return true;
  }

  // The menu shows this answer, above the input that sent it.
  function seen(exchange) {
    return !!exchange?.input && watched;
  }

  // Not seen, or seen while another input or a panel shows instead: told as when the menu is closed.
  function missed(exchange) {
    return !seen(exchange) || !displayed;
  }

  function describe(exchange) {
    return Exchanges.described(exchange, exchange === exchanges[exchanges.length - 1] && stage === "working", approval, activity, words.allowQuestion);
  }

  // For the menu, while it shows it (Plugin.turn).
  function report() {
    const last = exchanges[exchanges.length - 1];
    if (seen(last)) turn = describe(last);
  }

  // `after` runs once the turn is answered.
  function send(prompt, after = "", input = false, context = "") {
    prompt = prompt.trim();
    if (!prompt || busy || !settings.ask) return false;
    exchanges = Exchanges.sent(exchanges, prompt, after, input || watched);
    stage = "working";
    approval = "";
    activity = "";
    touched = false;
    streamed = "";
    sentAt = now = Math.floor(Date.now() / 1000);
    report();
    agent.turn([{ type: "text", text: prompt }].concat(context ? [{ type: "text", text: Exchanges.marked(context) }] : []));
    return true;
  }

  function close(outcome) {
    if (stage === "resuming") return resumed(outcome);
    flush();
    finish(Exchanges.closed(exchanges[exchanges.length - 1], outcome, words.noAnswer, Markup.hasTable));
  }

  // Replaced, not edited, so what draws it hears.
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

  function finish(answer) {
    const last = setLast(answer);
    stage = "idle";
    approval = "";
    if (seen(last)) report();
    if (missed(last)) notify(last.error || Markup.plain(last.reply));
    if (last.reply && !last.stopped) exec(last.after);
    if (touched) exec(settings.toolRun);
    if (!shown && missed(last)) unread = true;
    if (last.error && !last.stopped && !seen(last) && draft === "") draft = last.prompt;
  }

  function notify(text) {
    if (shown || !settings.notify) return;
    notifier.running = false;
    notifier.command = commandLine(settings.notify, title, text.split("\n")[0]);
    notifier.running = true;
  }

  // Allow or deny once; an agent offering neither for the answer is told it was cancelled. The next request it holds shows next.
  function answerApproval(allowed) {
    if (!approval) return;
    const what = approval;
    approval = "";
    const once = agent.answer(allowed);
    setLast({ steps: (exchanges[exchanges.length - 1].steps ?? []).concat([once ? words.approval(allowed, what) : words.notOnce(what)]) });
  }

  function copy() {
    Quickshell.clipboardText = exchanges[exchanges.length - 1].reply;
  }

  // The agent stays for the next turn (Acp.cancel).
  function stop() {
    if (busy) agent.cancel();
  }

  // The unsent prompt stays, but not a failed one put back for a retry.
  function reset() {
    stop();
    const last = exchanges[exchanges.length - 1];
    if (last?.error && draft === last.prompt) draft = "";
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

  // Kept as it changes, so it outlasts a reload.
  function keepDraft(text) {
    draft = text;
  }

  // True when the key was the panel's; Escape and the rest are the prompt's, which has the keys throughout.
  function act(key) {
    // Any key closes the list, but a modifier alone, which has no name.
    if (helping && key) {
      helping = false;
      return true;
    }
    // Tab would type a tab.
    if (key === "Tab" || key === "Backtab") return true;
    const entry = keys.find(entry => entry.key === key);
    return !!entry && entry.shows() && entry.run() !== false;
  }

  // Kept over a reload or a restart; the agent loads the conversation again on its next turn.
  readonly property var kept: ({ exchanges: exchanges, session: session, draft: draft })
  // Saved once taken, so a conversation being made never overwrites the one it takes; and once a turn settles, not per streamed piece.
  property bool taken: false
  onKeptChanged: save()
  onStageChanged: save()
  // And the moment a turn opens its session, so a restart mid-answer resumes that session.
  onSessionChanged: if (taken) Kept.set(name, kept)

  function save() {
    if (taken && stage === "idle") Kept.set(name, kept);
  }

  Component.onCompleted: take()

  function take() {
    const kept = Kept.value(name);
    if (kept) {
      exchanges = Exchanges.restored(kept.exchanges);
      session = kept.session;
      draft = kept.draft;
    }
    taken = true;
  }

  onVisitEnded: {
    visited = false;
    turn = null;
  }
  // An answer this visit missed, another input or panel showing, is read once its input shows it.
  onDisplayedChanged: if (displayed && visited && seen(exchanges[exchanges.length - 1])) unread = false

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
      root.activity = Exchanges.activityOf(title);
      if (root.settings.toolPattern && root.settings.toolPattern.test(title)) root.touched = true;
      root.report();
    }
    onRestarted: {
      root.activity = root.words.restarted;
      root.report();
    }
    onPermission: title => {
      root.approval = title;
      const last = root.exchanges[root.exchanges.length - 1];
      if (root.seen(last)) root.report();
      if (root.missed(last)) root.notify(root.words.allowQuestion(title));
    }
    onHistory: (role, chunk) => Exchanges.replayed(root.recalled, role, chunk)
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
