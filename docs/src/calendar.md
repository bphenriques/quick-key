# Calendar

`view = "calendar"` gives a level a month and, beside it, the events from the selected day on.

## Keys

- Arrows move the selected day by a day or a week, `Ctrl+↑↓` by a year. `?` lists these rather than the bar, as the grid shows the arrows.
- `Ctrl+←→` moves a month, `t` goes back to today.
- `Return` steps into the events: the arrows then move through them, the month following, and `ESC` returns. On an event, `Return` shows it whole in the events' place, its title and place unshortened and its end to the minute, until `ESC`.

A dot under a day marks each colour of its events, up to four; with more, the last is grey. The month and year head the grid, its keys sit on the bar, and a failed sync says why under the events.

The `calendar` status shows when the next event is, timed ones first, so a daily all-day event does not hold it; one under way says when it ends (`to 12:00`). Its fields are `title`, `when`, `more`: how many timed events start later today besides it (`+2`, empty with none), and `updated`: how old the events are, or `syncing...` while a sync runs. A Sync button in the level's bar shows only its icon, spinning while the sync runs, `updated` on hover; past `calendar.staleAfter` it turns warning with `updated` beside it:

```nix
bar.right = [ { key = "s"; desc = "Sync"; icon = "󰓦"; status = "calendar"; format = "{updated}"; cmd = config.programs.quick-key.calendarSync.exec.sync; } ];
```

Once something writes `calendar.file`, put `"calendar"` in the top bar beside the clock, so the next event shows without opening the month; a format names what it shows, shortened when the bar is crowded and whole on hover. Setting `menu.bar.left` replaces the starter's clock, so it names that too:

```nix
menu.bar.left = [
  { key = "c"; desc = "Calendar"; status = "clock"; view = "calendar"; }
  { desc = "Next"; status = "calendar"; format = "{when} {title} {more}"; }
];
```

## Events

Each day heads its events, with its year when not this one. A timed event takes one line, `09:00–09:15`, and its place a second. One running past its day says when it ends (`to Sat 18:00`), or only the date a week or more on (`to 3 Dec`), and the days it fills are all day. What is over dims, and today's timed events that are over fold into one line (`3 earlier`) until the arrows reach one. Today opens under its heading, or at its first timed event not over yet when the day's start would still leave it out of view, and any day, the last included, scrolls to the top. A row that does not fit whole is not drawn. On a level too narrow for titles beside the times, the times fold into each title's second line.

## The events file

The shell only reads `calendar.file`, watching it for changes; until it exists, the month shows alone. `calendarSync` writes it from a list of calendars (vdirsyncer, khal), but anything that writes this works:

```json
{
  "updated": "2026-11-12T14:30",
  "synced": { "from": "2026-09-11", "to": "2027-11-12" },
  "error": "personal: could not sync",
  "events": [
    { "title": "Dentist", "start": "2026-11-12T14:00", "end": "2026-11-12T15:00", "color": "#4285f4", "location": "Rua Augusta 120" },
    { "title": "Trip", "start": "2026-11-20", "end": "2026-11-22", "allDay": true, "color": "#33b679" }
  ]
}
```

- Times are local, without an offset. An all-day event's `end` is its last day.
- A repeating event is one entry per occurrence.
- `synced` is the first and last day the events cover: a day past them says `Not synced`, not `No events`. Without it, events show only within a year of today.
- `uid` tells apart two events alike in title, time and colour, so the keys reach each.
- `uid`, `location`, `synced`, `error` and `syncing: true` are optional.

`calendar.remind` reminds of each timed event once, `calendar.remindBefore` minutes before it starts, a restart of the shell repeating none.

## calendarSync

`calendarSync.enable` syncs 62 days back and a year ahead, from the calendars listed in `calendarSync.calendars`, and writes that range as `synced`. Cancelled events are left out. A sync that fails retries a minute later, then ever less often, up to every half hour.
