import qs

// Ask's commands, each given its arguments as $1, $2... (the protocol is in docs/src/plugins.md).
PluginSettings {
  // Given a prompt, the session ("" for a new one) and an image ("" for none), prints a JSON object per line; approvals are answered on its stdin.
  property string ask
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
  // What gives the prompt the keys again once Escape has taken them.
  property string key: "a"
  // How many lines tall the conversation is, like a level's width: declared, so the panel holds still (rule 4).
  property int lines: 14
}
