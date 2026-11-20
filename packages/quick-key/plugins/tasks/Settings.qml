import qs

// The tasks' commands, each given its arguments as $1, $2... (docs/src/tasks.md); `file` is the tasks file.
PluginSettings {
  // Given a task's id, ticks it off and writes the file again.
  property string done
  // Given a task's id, unticks it and writes the file again.
  property string reopen
  // Given a title, adds a task to the first list and writes the file again.
  property string add
  // Syncs, as the menu opens and after a tick.
  property string sync
  // Minutes old the file may be as the menu opens before a sync; one on every opening would keep the calendar syncing.
  property int syncAfter: 5
  // Minutes after which the last sync shows in warning.
  property int staleAfter: 120
  // The order to start in: due, priority, title or list; the `sort` action steps through them.
  property string sort: "due"
  // What the done ones show at the start: hidden, shown or only; the `completed` action steps through them.
  property string completed: "hidden"
  // Given a title and a time, as a timed task falls due; unset, no reminders.
  property string remind
}
