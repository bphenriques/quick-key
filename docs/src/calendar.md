# Calendar

`view = "calendar"` gives a level a month under its entries, titled by the month, weeks starting on `clock.firstDayOfWeek` (the locale's by default). The arrows move the selected day by a day or a week, unlisted since the grid shows them; the legend line has the rest: `Ctrl+←→` a month, `Ctrl+↑↓` a year, `t` back to today, and `Return` into the events.

Once `calendar.file` exists, the month shows events: a dot per colour under each day that has them (four at most), and beside it, as tall as the month, one list of every event under a heading per day, starting at the selected day (`No events` when it has none). The month is how you move through the list, as in Fantastical: `Return` focuses the events from the selected day on; the arrows then step through them, the selected day following, and Backspace or any other calendar key returns to the month. A click on an event focuses it. Events are all-day first, then by start: a bar in its colour, start over end, then title over location, one line when neither has a second; a timed event that fills the day reads as all-day. The `calendar` status shows the next event on a row, timed ones first so a daily all-day event does not hold it, and in the level's header how old the events are (`updated 08:30`, or `syncing…`); a failed sync says why on its own line under the legend. With the events in focus, the legend offers `↑↓ event` and `DEL back`.

The shell only reads the file, watching it for changes. `calendarSync` writes it from a list of calendars (vdirsyncer, khal); anything else can, replacing it whole:

```json
{
  "updated": "2026-11-12T14:30",
  "error": "personal: could not sync",
  "events": [
    { "title": "Dentist", "start": "2026-11-12T14:00", "end": "2026-11-12T15:00", "allDay": false, "color": "#4285f4", "location": "Rua Augusta 120" },
    { "title": "Trip", "start": "2026-11-20", "end": "2026-11-22", "allDay": true, "color": "#33b679" }
  ]
}
```

Times are local, without an offset; an all-day event's `start` and `end` are dates, `end` its last day. A repeating event is one entry per occurrence. `location` is optional, and line breaks in it or the title read as commas. `error` says why the last sync failed, over the events it kept, and `syncing: true` marks one under way; both are left out otherwise. `calendar.remind`, given an event's title and when, reminds of each timed event once, `calendar.remindBefore` minutes ahead (10). Events are shown, never acted on. `calendarSync` covers 62 days back and a year ahead, so months beyond show none. Its list starts as a commented sample at `calendarSync.calendars`, and saving it syncs; `calendarSync.exec.sync` syncs now, for a Sync entry.

