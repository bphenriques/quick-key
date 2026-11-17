# Tasks

The `tasks` plugin lists tasks on digits, and a digit ticks one off or unticks it. Its status counts the open tasks due by today, up to `9+`, in the warning tone when one is late; its fields are `title` (the most urgent), `count` and `updated`.

```nix
plugins.tasks = {
  file = config.programs.quick-key.calendarSync.tasksFile;
  inherit (config.programs.quick-key.calendarSync.exec) done reopen sync;
};
menu.entries = [ { key = "k"; desc = "Tasks"; status = "tasks"; list = "tasks"; } ];
```

Tasks sort by due date, undated last, a late one in the warning tone. A ticked task keeps its digit, dim and struck through, so the same key unticks it; the file drops it the next day. A pick while the last one still runs is dropped, as the file shows its outcome first.

The file is read on every change. Opening the menu syncs when it is five minutes old, and every tick syncs after it.

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

A calendar with `tasks: true` in its list syncs both ways over CalDAV, so a tick reaches its server; the others are only read. calendarSync writes its tasks with todoman, whose config it keeps beside the events (`todoman.py`), so `todo --config` on that file sees the same tasks and ids. A tick and a sync's rewrite of the file take turns, and a tick never waits on the network.
