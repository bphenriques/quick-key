# Ask

A panel to ask an agent something without leaving what you are doing. It opens where the menu does, in the same frame, and opening either closes the other. Its prompt sits under the conversation with the keys, and names who it asks until a turn says what `RET` does next. Its keys sit in the bar beside the top level's statuses. An answer that comes while the panel is hidden arrives as a notification, unless the menu shows it above the input that sent it.

`ask` is the agent: a command speaking [ACP](https://agentclientprotocol.com) on its stdio. It starts with the first turn and stays for the next, so a turn skips its start and its session's loading. After `idle` minutes without a turn it stops, and the next turn starts it again.

The answer streams in as Markdown, ACP's text format and the one text the shell renders rich. The conversation renders it, fetching nothing and running no HTML: an image shows as its alt text. The menu's island shows it plain.

```nix
# Claude, through Zed's ACP adapter; `open` resumes its session in a terminal.
plugins.ask = { title = "Claude"; ask = "claude-agent-acp"; open = "foot claude --resume"; };

# An agent on another machine, its stdio over SSH; a sync after any tool that writes the agenda.
plugins.ask = { ask = "ssh host hermes-acp"; cwd = "/srv/agent"; toolMatch = "^mcp__agenda__(?!list_)"; toolRun = "calendar-sync"; };
```

A turn resumes the session (`session/resume`, else `session/load`), or starts one and says so when the old one is gone. Approvals are the agent's permission requests, shown one at a time. Stopping cancels the turn, and an agent still answering two seconds later is stopped; the next turn waits for it. A failure ends the turn in alert, saying why ("Sign in to … first", the agent's own error), and the agent's stderr goes to the journal.

| Tested with | Version |
|---|---|
| ACP | protocol v1 |
| Hermes Agent (`hermes-acp`) | 0.22.7 |

Other ACP agents (Claude through `claude-agent-acp`, Codex through `codex-acp`, Gemini CLI, OpenCode, Goose) speak the same protocol and are untested here.

Keys:

- `RET` sends. `C-S-RET` sends and hides the panel, the answer arriving as a notification. `S-RET` breaks the line.
- `ESC` clears the prompt, then steps back: to the menu that opened the panel, else hiding it, as a click beside it does. The conversation is kept.
- `C-c` stops the run, cancelling what it waits to be allowed, and keeps what it had answered so far. Leaving never stops it.
- `C-y` allows an approval once and `C-n` denies it, the run going on. Neither answers for good: an agent offering only that hears the request cancelled. Each stays in the conversation as a dim line. `C-l` starts a new conversation, `C-o` moves it to a terminal, and `C-r`, between turns, lists past conversations.
- `C-C` (Shift with `C-c`, as terminals copy) copies the last answer, and `PgUp` and `PgDn` scroll the conversation. The prompt keeps the keys throughout, and the bar shows only those that act now.
- `C-?`, `?` with Ctrl since the prompt has the keys, lists the rest in the conversation's place. Any key closes the list. Its `legend` setting names those to show in the bar too (`[ "Page_Up" "Page_Down" ]`).

A question from an input starts a new conversation, as a quick-entry window does, the one it leaves staying in the agent's own list. History is that list (ACP's `session/list`, in `cwd`), in its order, each with its last activity, filtered in the menu as a shell's reverse search is. `RET` resumes one, its history replayed (`session/load`), and its own menu (`M-RET`) has `o`, which opens it in a terminal. An agent that cannot load them dims them, and one that cannot list them says so. An input that gives Ask its text takes `C-r` too.

Its status shows its glyph only while it has something to report: a run, an unread answer, an approval waiting on you. To ask from a key, bind `menu press Tab`: the menu opens with its input focused. Two agents are two plugins with `type = "ask"`, and a level's `input` may hand one its text (see [Input](menu.md#input)).

