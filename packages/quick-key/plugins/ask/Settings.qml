import qs

// Ask's agent and commands, each command given its arguments as $1, $2... (docs/src/plugins.md#ask).
PluginSettings {
  // The agent: a command speaking ACP on its stdio, kept running between turns.
  property string ask
  // Where its sessions work, on the agent's machine; unset, $HOME.
  property string cwd
  // Minutes without a turn before the agent is stopped; the next turn starts it again.
  property int idle: 10
  // A tool name (a regular expression) that makes `toolRun` run once the turn that used it ends.
  property string toolMatch
  property string toolRun
  // Given a file, prints it base64, as an image goes to the agent.
  property string encodeImage: "base64 -w0"
  // Given a title and a text, while the panel is hidden; prints `default` when clicked.
  property string notify: "notify-send --action=default=Open"
  // Given a file, writes the clipboard's image there, failing when it holds none.
  property string pasteImage: "sh -c 'for type in $(wl-paste --list-types); do case $type in image/*) exec wl-paste --type \"$type\" > \"$1\" ;; esac; done; exit 1' sh"
  // Given the session, opens it in a terminal.
  property string open
  // Its name, in the prompt and notifications; unset, the plugin's.
  property string title
  // Its glyph in the bar and notifications.
  property string glyph
  // The prompt's glyph, its own (the agent's face) over the one every input shares (glyphs.prompt).
  property string promptGlyph
  // What the empty prompt says, {title} for the title.
  property string placeholder: "Ask {title}"
  // How many lines tall the conversation is, like a level's width: declared, so the panel holds still (rule 4).
  property int lines: 14
}
