import qs

// The tasks' commands, each given its arguments as $1, $2... (docs/src/tasks.md); `file` is the tasks file.
PluginSettings {
  // Given a task's id, ticks it off and writes the file again.
  property string done
  // Given a task's id, unticks it and writes the file again.
  property string reopen
  // Syncs, as the menu opens and after a tick.
  property string sync
  // Given a title and a time, as a timed task falls due; unset, no reminders.
  property string remind
  property string glyph
}
