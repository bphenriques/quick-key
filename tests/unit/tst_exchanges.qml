import QtQuick
import QtTest
import "exchanges.js" as Exchanges

// A conversation's exchanges as its turns go, without an agent.
TestCase {
  name: "exchanges"

  function exchange(fields) {
    return Object.assign({ prompt: "q", reply: "", error: "", stopped: false, after: "", input: false }, fields);
  }

  // Asking again what failed replaces it, keeping its after unless given another; anything else is a new exchange.
  function test_sent() {
    const failed = [exchange({ prompt: "first", reply: "one" }), exchange({ prompt: "again", error: "No answer", after: "echo done" })];
    const retried = Exchanges.sent(failed, "again", "", true);
    compare(retried.length, 2);
    compare(retried[1], exchange({ prompt: "again", after: "echo done", input: true }));
    compare(Exchanges.sent(failed, "again", "echo other", false)[1].after, "echo other");
    compare(Exchanges.sent(failed, "other", "", false).map(each => each.prompt), ["first", "again", "other"]);
    compare(Exchanges.sent([], "hi", "", false), [exchange({ prompt: "hi" })]);
  }

  // Answered, its reply, a table marked; stopped, what streamed; else nothing, and why.
  function test_closed() {
    const streaming = exchange({ reply: "| a |\n|---|" });
    const table = text => text.includes("|---|");
    compare(Exchanges.closed(streaming, { answered: true }, "No answer", table), exchange({ reply: "| a |\n|---|", table: true }));
    compare(Exchanges.closed(exchange({}), { answered: true }, "No answer", table), exchange({ error: "No answer", table: false }));
    compare(Exchanges.closed(streaming, { stopped: true }, "No answer", table), exchange({ reply: "| a |\n|---|", error: "Stopped", stopped: true, table: false }));
    compare(Exchanges.closed(streaming, { error: "Agent gone" }, "No answer", table), exchange({ error: "Agent gone", table: false }));
  }

  // Blocked on an approval while working; a stopped answer keeps what came, the stop after it.
  function test_described() {
    const asking = what => "Allow " + what + "?";
    const working = Exchanges.described(exchange({ reply: "so far" }), true, "", "grep", asking);
    compare([working.phase, working.text, working.activity], ["working", "so far", "grep"]);
    const blocked = Exchanges.described(exchange({}), true, "rm", "grep", asking);
    compare([blocked.phase, blocked.kind, blocked.text, blocked.activity], ["blocked", "permission", "Allow rm?", ""]);
    const stopped = Exchanges.described(exchange({ reply: "half", error: "Stopped", stopped: true }), false, "", "", asking);
    compare([stopped.phase, stopped.text], ["idle", "half\n\nStopped"]);
    compare(Exchanges.described(exchange({ error: "Failed" }), false, "", "", asking).phase, "error");
    compare(Exchanges.described(exchange({ reply: "done", steps: ["Allowed: rm"] }), false, "", "", asking).steps, ["Allowed: rm"]);
  }

  // A turn a restart cut short reads as stopped; one answered or failed stays as it was.
  function test_restored() {
    const cut = Exchanges.restored([exchange({ reply: "one" }), exchange({ prompt: "cut" })]);
    compare(cut[1], exchange({ prompt: "cut", error: "Stopped", stopped: true }));
    const answered = [exchange({ reply: "one" })];
    verify(Exchanges.restored(answered) === answered);
    compare(Exchanges.restored([]), []);
  }

  // Chunks group into exchanges, a user's after a reply starting the next; an agent's before any user's is a reply without a prompt.
  function test_replayed() {
    const history = [];
    [["agent", "hello"], ["user", "what "], ["user", "was it?"], ["agent", "from "], ["agent", "before"], ["user", "next"]].forEach(([role, chunk]) => Exchanges.replayed(history, role, chunk));
    compare(history, [{ prompt: "", reply: "hello" }, { prompt: "what was it?", reply: "from before" }, { prompt: "next", reply: "" }]);
  }

  function test_typed() {
    // As an agent joins the blocks it got, with a newline (Hermes) or nothing.
    compare(Exchanges.typed("milk\n" + Exchanges.marked("From the menu's Tasks input")), "milk");
    compare(Exchanges.typed("milk" + Exchanges.marked("Tasks")), "milk");
    compare(Exchanges.typed("see the note [1]"), "see the note [1]");
  }

  function test_activityOf() {
    compare(Exchanges.activityOf("mcp__meals__plan_week"), "meals");
    compare(Exchanges.activityOf("Read"), "Read");
  }
}
