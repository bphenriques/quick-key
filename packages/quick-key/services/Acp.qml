pragma ComponentBehavior: Bound

import QtQuick
import Quickshell.Io

// An ACP client (agentclientprotocol.com, protocol v1) for one agent on its stdio, one turn at a time: it starts the agent, keeps it for the next turns until `idle` minutes pass, opens or loads the session, and streams the answer.
Item {
  id: root

  // The agent's command line, as `sh -c` runs it; its name, in the errors.
  property var command: []
  property string name
  // Where its sessions work, on the agent's machine.
  property string cwd
  property int idle: 10
  // The conversation: "" until a turn opens one, which the next turns carry on.
  property string session: ""

  // What it can do, once started: carry on an earlier conversation (`load`), list them (`list`).
  property bool canLoad: false
  property bool canList: false

  // The answer as it streams in; a tool it started; it had to start a new conversation; it asks to be allowed `title` (answered by `answer`).
  signal text(string chunk)
  // A loaded conversation's history, as the agent replays it: `role` user or agent, a piece of its text.
  signal history(string role, string chunk)
  signal tool(string title)
  signal restarted
  signal permission(string title)
  // The turn's end: `answered` (`stopped` when cancelled, `cut` when it ran out of tokens), else the `error` the user reads.
  signal ended(var outcome)

  readonly property int authRequired: -32000
  readonly property var stopped: ({ cancelled: "Stopped", max_turn_requests: "Stopped after too many steps", refusal: "Refused to answer" })

  // Its own state: the process initialized and who waits for it, the session it has open, the work under way (a turn, or a load replaying) and the permission it waits on.
  QtObject {
    id: internal

    property bool ready: false
    property var waiters: null
    property string opened: ""
    property bool replaying: false
    // Each piece of work's ticket, the one under way, and whether it ended.
    property int tickets: 0
    property int current: 0
    property bool done: true
    property bool prompting: false
    property bool spoke: false
    property var waiting: null
    property string complaint: ""
    property int nextId: 1
    property var pending: ({})
  }

  // A turn: `blocks` are ACP content blocks (text, image).
  function turn(blocks) {
    const live = begin();
    connect(() => live() && open(live, () => ask(live, blocks)), why => live() && fail(why));
  }

  // An earlier conversation, between turns: its history replayed through `history`, then `ended` with `loaded`.
  function load(id) {
    if (!internal.done) return;
    session = id;
    const live = begin();
    internal.replaying = true;
    connect(() => live() && open(live, () => end({ loaded: true })), why => live() && fail(why));
  }

  // Its conversations where it works, as it orders them: then([{ sessionId, title, updatedAt }]), else then(null, why).
  function list(then) {
    connect(() => {
      if (!canList) return then(null, name + " keeps no list of conversations");
      request("session/list", { cwd: cwd }, (error, result) => {
        if (internal.done) idleTimer.restart();
        then(error ? null : Array.from(result.sessions ?? []), error?.message ?? "");
      });
    }, why => then(null, why));
  }

  function answer(allowed) {
    if (!internal.waiting) return;
    const kinds = allowed ? ["allow_once", "allow_always"] : ["reject_once", "reject_always"];
    const option = kinds.map(kind => internal.waiting.options.find(offered => offered.kind === kind)).find(offered => offered);
    respond(internal.waiting.id, { outcome: option ? { outcome: "selected", optionId: option.optionId } : { outcome: "cancelled" } });
    internal.waiting = null;
  }

  // Ends the turn now; the agent hears a cancel, and is stopped if it still answers two seconds later.
  function cancel() {
    if (internal.done) return;
    answer(false);
    if (internal.prompting) {
      notify("session/cancel", { sessionId: session });
      cancelling.restart();
    } else stop();
    end({ stopped: true });
  }

  function stop() {
    process.running = false;
  }

  // A piece of work, the one under way from now: `live()`, for its callbacks, is false once another begins or it ends.
  function begin() {
    const ticket = internal.current = ++internal.tickets;
    internal.done = false;
    internal.spoke = false;
    idleTimer.stop();
    return () => ticket === internal.current && !internal.done;
  }

  function end(outcome) {
    if (internal.done) return;
    internal.done = true;
    internal.replaying = false;
    internal.waiting = null;
    idleTimer.restart();
    ended(outcome);
  }

  function fail(message) {
    end({ error: message });
  }

  function refusal(error) {
    return error.code === authRequired ? "Sign in to " + name + " first" : error.message;
  }

  // Started and initialized once for every caller waiting meanwhile: each hears `then()`, or `failed(why)`.
  function connect(then, failed) {
    if (internal.ready) return then();
    if (internal.waiters) return internal.waiters.push({ then, failed });
    internal.waiters = [{ then, failed }];
    if (!process.running) {
      internal.complaint = "";
      process.command = command;
      process.running = true;
    }
    request("initialize", { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: false, writeTextFile: false }, terminal: false }, clientInfo: { name: "quick-key", version: "1" } }, (error, result) => {
      const queued = internal.waiters;
      internal.waiters = null;
      const problem = error ? error.message : result.protocolVersion !== 1 ? name + " speaks ACP v" + result.protocolVersion + ", quick-key v1" : "";
      if (!problem) {
        internal.ready = true;
        canLoad = !!result.agentCapabilities?.loadSession;
        canList = !!result.agentCapabilities?.sessionCapabilities?.list;
      }
      for (const waiter of queued) problem ? waiter.failed(problem) : waiter.then();
    });
  }

  // Open in this process already, else loaded, else a new one, saying so when the old one is gone.
  function open(live, then) {
    if (session && internal.opened === session) return then();
    const use = id => {
      session = internal.opened = id;
      then();
    };
    const fresh = replaced => request("session/new", { cwd: cwd, mcpServers: [] }, (error, result) => {
      if (!live()) return;
      if (error) return fail(refusal(error));
      if (replaced) restarted();
      use(result.sessionId);
    });
    if (!session || !canLoad) return fresh(!!session);
    request("session/load", { sessionId: session, cwd: cwd, mcpServers: [] }, error => {
      if (!live()) return;
      if (error?.code === authRequired) return fail(refusal(error));
      if (error) return fresh(true);
      use(session);
    });
  }

  function ask(live, blocks) {
    internal.prompting = true;
    request("session/prompt", { sessionId: session, prompt: blocks }, (error, result) => {
      internal.prompting = false;
      if (!live()) return;
      if (error) return fail(error.message);
      const reason = result.stopReason;
      if (reason === "end_turn" || (reason === "max_tokens" && internal.spoke)) return internal.spoke ? end({ answered: true, cut: reason === "max_tokens" }) : fail(name + " answered with nothing");
      end({ stopped: reason === "cancelled", error: stopped[reason] ?? "Stopped: " + reason });
    });
  }

  function receive(message) {
    if (message.method === "session/update") {
      const update = message.params.update;
      const role = { user_message_chunk: "user", agent_message_chunk: "agent" }[update.sessionUpdate];
      // A load replays the history, which only `load` asked for; a turn's own answer is its own.
      if (internal.replaying && role && update.content?.type === "text") return history(role, update.content.text);
      if (!internal.prompting || internal.done) return;
      if (update.sessionUpdate === "agent_message_chunk" && update.content?.type === "text") {
        internal.spoke = true;
        text(update.content.text);
      } else if (update.sessionUpdate === "tool_call") tool(update.title ?? "");
    } else if (message.method === "session/request_permission") {
      if (internal.done) return respond(message.id, { outcome: { outcome: "cancelled" } });
      internal.waiting = { id: message.id, options: message.params.options ?? [] };
      permission(message.params.toolCall?.title || "an action");
    } else if (message.method && message.id !== undefined) {
      // A request this client said it does not serve (files, terminals).
      write({ jsonrpc: "2.0", id: message.id, error: { code: -32601, message: "Method not found" } });
    } else {
      const reply = internal.pending[message.id];
      delete internal.pending[message.id];
      if (reply) reply(message.error ?? null, message.result ?? null);
    }
  }

  function request(method, params, reply) {
    const id = internal.nextId++;
    internal.pending[id] = reply;
    write({ jsonrpc: "2.0", id: id, method: method, params: params });
  }

  function notify(method, params) {
    write({ jsonrpc: "2.0", method: method, params: params });
  }

  function respond(id, result) {
    write({ jsonrpc: "2.0", id: id, result: result });
  }

  function write(message) {
    process.write(JSON.stringify(message) + "\n");
  }

  Timer {
    id: idleTimer
    interval: root.idle * 60000
    onTriggered: if (internal.done) root.stop()
  }

  Timer {
    id: cancelling
    interval: 2000
    onTriggered: if (internal.prompting) root.stop()
  }

  Process {
    id: process
    stdinEnabled: true

    stdout: SplitParser {
      onRead: line => {
        let message;
        try {
          message = JSON.parse(line);
        } catch (error) {
          return console.warn("acp: not JSON, ignored:", line);
        }
        root.receive(message);
      }
    }

    // Logged, so its own account of a failure is in the journal.
    stderr: SplitParser {
      onRead: line => {
        if (!line.trim()) return;
        console.info("acp:", line);
        internal.complaint = line.trim();
      }
    }

    // The turn ends first, so what then hears its reply never come (a list, a load's fallback) finds it over.
    onExited: {
      const why = internal.complaint || root.name + " ended before answering";
      const unanswered = Object.values(internal.pending);
      internal.ready = false;
      internal.opened = "";
      internal.prompting = false;
      internal.pending = {};
      root.fail(why);
      for (const reply of unanswered) reply({ message: why }, null);
    }
  }
}
