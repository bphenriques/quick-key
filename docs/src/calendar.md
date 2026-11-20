# Calendar

`view = "calendar"` gives a level a month and, beside it, the events from the selected day on.

## Keys

- Arrows move the selected day by a day or a week.
- `Ctrl+←→` moves a month, `Ctrl+↑↓` a year, `t` goes back to today.
- `Return` steps into the events: the arrows then move through them, the month following, and `ESC` returns.

A dot under a day marks each colour of its events. The `calendar` status shows when the next event is, timed ones first, so a daily all-day event does not hold it; its fields are `title`, `when` and `updated`, how old the events are, `syncing...` while a sync runs. The month and year head the grid, its keys sit on the bar, and a failed sync says why under the events. A Sync button in the level's bar shows only its icon, spinning while the sync runs, `updated` on hover; past `calendar.staleAfter` it turns warning with `updated` beside it:

```nix
header.right = [ { key = "s"; desc = "Sync"; icon = "<glyph>"; status = "calendar"; format = "{updated}"; cmd = config.programs.quick-key.calendarSync.exec.sync; } ];
```

## The events file

The shell only reads `calendar.file`, watching it for changes. `calendarSync` writes it from a list of calendars (vdirsyncer, khal), but anything that writes this works:

```json
{
  "updated": "2026-11-12T14:30",
  "error": "personal: could not sync",
  "events": [
    { "title": "Dentist", "start": "2026-11-12T14:00", "end": "2026-11-12T15:00", "color": "#4285f4", "location": "Rua Augusta 120" },
    { "title": "Trip", "start": "2026-11-20", "end": "2026-11-22", "allDay": true, "color": "#33b679" }
  ]
}
```

- Times are local, without an offset. An all-day event's `end` is its last day.
- A repeating event is one entry per occurrence.
- `location`, `error` and `syncing: true` are optional.

## Reminders

`calendar.remind` is run with an event's title and time, `calendar.remindBefore` minutes (10) before each timed event. It defaults to `notify-send`; empty turns reminders off.

## calendarSync

`calendarSync.enable` syncs 62 days back and a year ahead. Its calendars start as a commented sample at `calendarSync.calendars`, and saving the list syncs. `calendarSync.exec.sync` syncs now, for a Sync entry.
