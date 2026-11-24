# Tasks

The `tasks` plugin lists tasks on digits, and a digit ticks one off or unticks it. A level's `input` adds a task by its title, raw, to the first list (see [Input](menu.md#input)).

A tick shows at once. An added task shows at once in the input, with a spinner until its command is done and the file lists it, no row moving under the keys meanwhile, so a command that reads a date out of the text (an agent) shows it is working. Each command runs after the ones before it. One that fails shows the file's state again and says so in the level, as a failed sync does, until the menu next opens; a tick the file still does not have five seconds after its command shows the file's state again too.

Its status counts the late tasks beside an alarm, in the warning tone, when there are any, else the open tasks due by today, up to `9+`. Its fields are `title` (the most urgent: late first, then by due, whatever the sort), `count` and `updated`.

```nix
plugins.tasks = {
  file = config.programs.quick-key.calendarSync.tasksFile;
  inherit (config.programs.quick-key.calendarSync.exec) done reopen add sync;
  sort = "due";
  completed = "hidden";
};
menu.entries = [ { key = "k"; desc = "Tasks"; status = "tasks"; list = "tasks"; submenu = [
  { key = "s"; desc = "Sort"; action = "sort"; }
  { key = "c"; desc = "Done"; action = "completed"; }
]; } ];
```

`sort` orders them: `due` (undated last), `priority` (highest first, unset last), `title`, or `list` (by list, then due). Under each, those done before the menu opened come after the open ones. `completed` says what the done ones show: `hidden` hides those done before the menu opened, still found by filtering (`/`); `shown` shows them; `only` shows only them, each with when it was done in place of its due date. The plugin's `sort` and `completed` actions step through these, kept over a restart, the one in use beside them (`Sort by due date`, `Done hidden`) and as their icon (the glyphs `sorts` and `completed`, by value).

A task's due date is on its right, after its priority as a glyph (the glyphs `priorities`: `high` for 1 to 4, `low` for 6 to 9, as iCalendar groups them; medium, 5, shows none), and its list's colour as a dot at the end while the file holds more than one list. A task is late once its time has passed, or the day after its date when it has no time: in the warning tone, with an alarm before its date. A ticked task keeps its digit, dim and struck through, so the same key unticks it. With none, the level says so.

`remind`, given a task's title and its time, runs once as each timed task falls due. One that falls due unseen, the machine asleep or the shell off, runs at the next minute; a new session skips those already past.

The file is read on every change. Opening the menu syncs once it is `syncAfter` minutes old, and every tick syncs after it. Past `staleAfter` minutes its last sync shows in warning, and a Sync button in its level's bar shows it as the calendar's does ([Calendar](calendar.md)).

## The tasks file

One line, so the plugin reads it as its state:

```json
{"updated": "2026-11-17T14:30", "error": "personal: could not sync", "tasks": [
  {"id": "12", "title": "Pay the electricity", "due": "2026-11-20T18:00", "done": false, "list": "personal", "priority": 1, "color": "#ff8c00"},
  {"id": "13", "title": "Call the plumber", "due": "2026-11-18", "done": true, "completed": "2026-11-17T09:12", "list": "personal", "color": "#ff8c00"}]}
```

- `updated` is when the lists last synced, left out until one has; `error` is why the last sync failed. A tick or an add writes neither anew, so a file that cannot sync shows its age.
- Times are local, without an offset; a due date without a time is due that day.
- `id` is what `done` and `reopen` are given, with `title`, so a command can tell whether the id still names that task.
- `priority` runs from 1, the highest, to 9; unset or 0, none.
- It holds the open tasks, and those done in the last 14 days, so a mistaken tick can be undone and `completed` has some to show.

## calendarSync

A calendar with `tasks: true` in its list syncs both ways over CalDAV, so a tick or an added task reaches its server; the others are only read, and new tasks go to the first. `exec.done`, `exec.reopen` and `exec.add` are the tasks plugin's commands.

calendarSync reads its tasks with todoman, whose config it keeps beside the events (`todoman.py`), so `todo --config` on that file sees the same tasks. A tick edits the task's file, changing only its status, completion and percent done; todoman, which writes a task anew from what it reads, only adds a task and ticks off a repeating one. A task's `id` is todoman's, which numbers tasks anew as their files change, so a tick acts only on a task the file lists with its title, open for a tick and done for an untick, else fails ("tasks changed, try again"), touching nothing. Two such tasks of one title fail too, as an id may have moved to either, and so does a file holding more than one task (a series with instances of its own): tick them in your calendar app.

Ticking a repeating task makes its next one; unticking reopens only the one ticked and leaves the next, to delete in your calendar app if unwanted. todoman writes both anew: the one ticked loses a start not before its due time, a language, categories on two lines and its times' zone, and the next one also loses its reminders, its links (`URL`, `RELATED-TO`) and an app's own properties (`X-`), its `COUNT` starting over, so a series meant to end never does. Your calendar app keeps a series whole; tick repeating tasks there.

A tick or an add and a sync's rewrite of the file take turns, and neither waits on the network.
