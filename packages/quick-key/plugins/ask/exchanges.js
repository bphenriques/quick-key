.pragma library

// The conversation's exchanges as a turn goes, pure, so a unit test reads them without an agent (tests/unit): each { prompt, reply, error, stopped, after, input, table, steps }.

// A turn sent: asking again what failed replaces that exchange, keeping its `after`.
function sent(exchanges, prompt, after, input) {
  const last = exchanges[exchanges.length - 1];
  const retried = last && last.error && last.prompt === prompt;
  const kept = retried ? exchanges.slice(0, -1) : exchanges;
  return kept.concat([{ prompt, reply: "", error: "", stopped: false, after: after || (retried ? last.after : ""), input }]);
}

// The last exchange as its turn ends (Acp's outcome): stopped, what streamed stays, as people stop because they have read enough; answered with nothing, `none`.
function closed(last, outcome, none, hasTable) {
  const reply = outcome.answered || outcome.stopped ? last.reply : "";
  const error = outcome.answered ? (reply ? "" : none) : outcome.error ?? "Stopped";
  return Object.assign({}, last, { reply, error, stopped: !outcome.answered && !!outcome.stopped, table: !!(outcome.answered && hasTable(reply)) });
}

// As an Exchange draws it (Phase): blocked on an approval while `working`, its question then `asking` it.
function described(exchange, working, approval, activity, asking) {
  const phase = working ? (approval ? "blocked" : "working") : exchange.stopped ? "idle" : exchange.error ? "error" : "done";
  const kind = phase === "blocked" ? "permission" : "";
  return {
    question: exchange.prompt,
    // A stopped answer keeps what came, the stop on a line after it.
    text: kind === "permission" ? asking(approval) : exchange.stopped && exchange.reply ? exchange.reply + "\n\n" + exchange.error : exchange.error || exchange.reply,
    phase: phase,
    kind: kind,
    activity: phase === "working" ? activity : "",
    table: !!exchange.table,
    steps: exchange.steps ?? []
  };
}

// Kept over a restart: a turn the restart cut short reads as stopped, as one you stopped does, not as answered with nothing.
function restored(exchanges) {
  const last = exchanges[exchanges.length - 1];
  return last && !last.reply && !last.error ? exchanges.slice(0, -1).concat([Object.assign({}, last, { error: "Stopped", stopped: true })]) : exchanges;
}

// A chunk of the history an agent replays, added to `history` in place, as it is built whole before it shows: a user's after a reply starts the next exchange.
function replayed(history, role, chunk) {
  const last = history[history.length - 1];
  if (role === "user" && (!last || last.reply)) history.push({ prompt: chunk, reply: "" });
  else if (role === "user") last.prompt += chunk;
  else if (last) last.reply += chunk;
  else history.push({ prompt: "", reply: chunk });
}

// What a tool's run shows: an MCP tool by its server (mcp__meals__plan_week: meals), the rest by name.
function activityOf(title) {
  return title.startsWith("mcp__") ? title.split("__")[1] : title;
}
