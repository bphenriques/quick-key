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

  // The answer as it streams in; a tool it started; it had to start a new conversation; it asks to be allowed `title` (answered by `answer`).
  signal text(string chunk)
  signal tool(string title)
  signal restarted
  signal permission(string title)
  // The turn's end: `answered` (`stopped` when cancelled, `cut` when it ran out of tokens), else the `error` the user reads.
  signal ended(var outcome)

  // Its own state: the process initialized, what it can do, the session it has open, the turn under way and the permission it waits on.
  property bool ready: false
  property bool canLoad: false
  property string opened: ""
  property int turns: 0
  property int current: 0
  property bool done: true
  property bool prompting: false
  property bool spoke: false
  property var waiting: null
  property string complaint: ""
  property int nextId: 1
  property var pending: ({})

  readonly property int authRequired: -32000
  readonly property var stopped: ({ cancelled: "Stopped", max_turn_requests: "Stopped after too many steps", refusal: "Refused to answer" })

  // A turn: `blocks` are ACP content blocks (text, image).
  function turn(blocks) {
    const ticket = current = ++turns;
    done = false;
    spoke = false;
    idleTimer.stop();
    const live = () => ticket === current && !done;
    connect(live, () => open(live, () => ask(live, blocks)));
  }

  function answer(allowed) {
    if (!waiting) return;
    const kinds = allowed ? ["allow_once", "allow_always"] : ["reject_once", "reject_always"];
    const option = kinds.map(kind => waiting.options.find(offered => offered.kind === kind)).find(offered => offered);
    respond(waiting.id, { outcome: option ? { outcome: "selected", optionId: option.optionId } : { outcome: "cancelled" } });
    waiting = null;
  }

  // Ends the turn now; the agent hears a cancel, and is stopped if it still answers two seconds later.
  function cancel() {
    if (done) return;
    answer(false);
    if (prompting) {
      notify("session/cancel", { sessionId: session });
      cancelling.restart();
    } else stop();
    end({ stopped: true });
  }

  function stop() {
    process.running = false;
  }

  function end(outcome) {
    if (done) return;
    done = true;
    waiting = null;
    idleTimer.restart();
    ended(outcome);
  }

  function fail(message) {
    end({ error: message });
  }

  function refusal(error) {
    return error.code === authRequired ? "Sign in to " + name + " first" : error.message;
  }

  function connect(live, then) {
    if (ready) return then();
    if (!process.running) {
      complaint = "";
      process.command = command;
      process.running = true;
    }
    request("initialize", { protocolVersion: 1, clientCapabilities: { fs: { readTextFile: false, writeTextFile: false }, terminal: false }, clientInfo: { name: "quick-key", version: "1" } }, (error, result) => {
      if (!live()) return;
      if (error) return fail(error.message);
      if (result.protocolVersion !== 1) return fail(name + " speaks ACP v" + result.protocolVersion + ", quick-key v1");
      ready = true;
      canLoad = !!result.agentCapabilities?.loadSession;
      then();
    });
  }

  // Open in this process already, else loaded, else a new one, saying so when the old one is gone.
  function open(live, then) {
    if (session && opened === session) return then();
    const use = id => {
      session = opened = id;
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
    prompting = true;
    request("session/prompt", { sessionId: session, prompt: blocks }, (error, result) => {
      prompting = false;
      if (!live()) return;
      if (error) return fail(error.message);
      const reason = result.stopReason;
      if (reason === "end_turn" || (reason === "max_tokens" && spoke)) return spoke ? end({ answered: true, cut: reason === "max_tokens" }) : fail(name + " answered with nothing");
      end({ stopped: reason === "cancelled", error: stopped[reason] ?? "Stopped: " + reason });
    });
  }

  function receive(message) {
    if (message.method === "session/update") {
      const update = message.params.update;
      // A load replays the history; only the turn's own answer counts.
      if (!prompting || done) return;
      if (update.sessionUpdate === "agent_message_chunk" && update.content?.type === "text") {
        spoke = true;
        text(update.content.text);
      } else if (update.sessionUpdate === "tool_call") tool(update.title ?? "");
    } else if (message.method === "session/request_permission") {
      if (done) return respond(message.id, { outcome: { outcome: "cancelled" } });
      waiting = { id: message.id, options: message.params.options ?? [] };
      permission(message.params.toolCall?.title || "an action");
    } else if (message.method && message.id !== undefined) {
      // A request this client said it does not serve (files, terminals).
      write({ jsonrpc: "2.0", id: message.id, error: { code: -32601, message: "Method not found" } });
    } else {
      const reply = pending[message.id];
      delete pending[message.id];
      if (reply) reply(message.error ?? null, message.result ?? null);
    }
  }

  function request(method, params, reply) {
    const id = nextId++;
    pending[id] = reply;
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
    onTriggered: if (root.done) root.stop()
  }

  Timer {
    id: cancelling
    interval: 2000
    onTriggered: if (root.prompting) root.stop()
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
        root.complaint = line.trim();
      }
    }

    onExited: {
      root.ready = false;
      root.opened = "";
      root.prompting = false;
      root.pending = {};
      root.fail(root.complaint || root.name + " ended before answering");
    }
  }
}
