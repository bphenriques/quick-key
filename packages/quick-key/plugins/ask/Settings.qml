import qs
import qs.ui

// Ask's agent and commands, each command given its arguments as $1, $2... (docs/src/ask.md).
PluginSettings {
  // Its glyph in a bar, so a turn waiting on you shows there too.
  glyph: Glyphs.conversation
  // Required: the agent, a command speaking ACP on its stdio, kept running between turns.
  property string ask
  // Where its sessions work, on the agent's machine; unset, $HOME.
  property string cwd
  // Minutes without a turn before the agent is stopped; the next turn starts it again.
  property int idle: 10
  // A tool name pattern (a regular expression): `toolRun` runs once a turn that used a matching tool ends.
  property string toolMatch
  property string toolRun
  // toolMatch compiled once; null when unset or not a pattern, which problems() names.
  readonly property var toolPattern: {
    try {
      return toolMatch ? new RegExp(toolMatch) : null;
    } catch (error) {
      return null;
    }
  }
  // Given a title and a text, tells of an answer while the panel is hidden, each replacing the last by its tag; printing `default` (a click) shows the panel.
  property string notify: "notify-send --app-name=\"$1\" --action=default=Open --hint=string:x-dunst-stack-tag:ask --"
  // Given the session, opens it in a terminal.
  property string open
  // The prompt's glyph, its own (the agent's face) over the one every input shares (glyphs.prompt).
  property string promptGlyph
  // What the empty prompt says, {title} for the title.
  property string placeholder: "Ask {title}..."
  // The conversation's height, in lines, declared so the panel holds still.
  property int lines: 14

  function problems() {
    return (ask ? [] : ["needs ask, the command it asks"]).concat(toolMatch && !toolPattern ? ["sets toolMatch to what is not a regular expression"] : []);
  }
}
