import qs

// Ask's commands, each given its arguments as $1, $2... (the protocol is in docs/src/plugins.md).
PluginSettings {
  // Given a prompt, the session ("" for a new one) and an image ("" for none), prints a JSON object per line.
  property string ask
  // Given the run and allow or deny.
  property string approve
  // Given the run.
  property string stop
  // Given a title and a text, while the panel is hidden; prints `default` when clicked.
  property string notify
  // Given a file, writes the clipboard's image there, failing when it holds none.
  property string pasteImage
  // Given the session, opens it in a terminal.
  property string open
  // The header; unset, the plugin's name and no glyph.
  property string title
  property string glyph
}
