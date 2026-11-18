# Tasks

The `tasks` plugin lists tasks on digits, and a digit ticks one off or unticks it. A level's `input` adds a task by its title, raw, to the first list (see [Input](menu.md#input)). A tick shows at once, and an added task at once with a spinner until its command is done, so a command that reads a date out of the text (an agent) shows it is working; its command runs after the ones before it, and one that fails shows the file's state again and says so in the level, as a failed sync does, until the menu next opens. Its status counts the late tasks beside an alarm, in the warning tone, when there are any, else the open tasks due by today, up to `9+`; its fields are `title` (the most urgent), `count` and `updated`.

```nix
plugins.tasks = {
  file = config.programs.quick-key.calendarSync.tasksFile;
  inherit (config.programs.quick-key.calendarSync.exec) done reopen sync;
};
menu.entries = [ { key = "k"; desc = "Tasks"; status = "tasks"; list = "tasks"; } ];
```

Tasks sort by due date, undated last, a late one in the warning tone with an alarm before its date. A ticked task keeps its digit, dim and struck through, so the same key unticks it; the file drops it the next day. With none, the level says so.

The file is read on every change. Opening the menu syncs when it is `syncAfter` minutes old (5), and every tick syncs after it. Past `staleAfter` minutes (120), its last sync shows in warning, as the calendar's does past `calendar.staleAfter`.

## The tasks file

One line, so the plugin reads it as its state:

```json
{"updated": "2026-11-17T14:30", "error": "personal: could not sync", "tasks": [
  {"id": "8", "title": "Pay the electricity", "due": "2026-11-20T18:00", "done": false, "color": "#ff8c00"},
  {"id": "3", "title": "Call the plumber", "due": "2026-11-18", "done": false, "color": "#ff8c00"}]}
```

- Times are local, without an offset; a due date without a time is due that day.
- `id` is what `done` and `reopen` are given. It need not outlast the next write.
- Open tasks, and those done today, so a mistaken tick can be undone.

## calendarSync

A calendar with `tasks: true` in its list syncs both ways over CalDAV, so a tick or an added task reaches its server; the others are only read, and new tasks go to the first. `exec.done`, `exec.reopen` and `exec.add` are the tasks plugin's commands. calendarSync writes its tasks with todoman, whose config it keeps beside the events (`todoman.py`), so `todo --config` on that file sees the same tasks and ids. A tick or an add and a sync's rewrite of the file take turns, and neither waits on the network.
