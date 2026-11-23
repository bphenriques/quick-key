import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
import qs.widgets.menu
import qs.widgets.menu.calendar

// The calendar's dates and the events it shows on them; the events are events.json's, around 12 November 2026.
ShellRoot {
  // An event's times on a day, as the time column says them.
  function times(title, day) {
    const row = Calendar.timeline.find(row => row.event.title === title && row.key === Clock.dayKey(day));
    return events.times(row.event, row.day).join("|");
  }

  // Replaces the events file, whole, as a sync does.
  function write(json) {
    Quickshell.execDetached(["sh", "-c", 'printf "%s" "$2" > "$1.tmp" && mv "$1.tmp" "$1"', "sh", Config.calendar.file, JSON.stringify(json)]);
  }

  function rows(title) {
    return Calendar.timeline.filter(row => row.event.title === title);
  }

  Suite {
    id: suite
    cases: [
      {
        name: "a month or year away keeps the day, or the month's last when it has fewer",
        until: () => [[new Date(2027, 0, 31), [0, 1, 0]], [new Date(2028, 1, 29), [1, 0, 0]], [new Date(2026, 11, 31), [0, 0, 1]]].map(([from, move]) => {
          menu.viewModels.calendar.select(from);
          menu.viewModels.calendar.moveSelected(...move);
          return Clock.dayKey(menu.viewModels.calendar.selected);
        }).join() === "2027-02-28,2029-02-28,2027-01-01"
      },
      {
        name: "an event shows on every day it overlaps, all-day ones first",
        until: () => Calendar.timeline.map(row => row.key.slice(8) + " " + row.event.title).join() ===
          "12 Holiday,12 Night shift,13 Night shift,14 Night shift,20 Trip,21 Trip,25 Call,26 Standup,26 Standup"
      },
      {
        name: "a day gives its events and their colours, each once, for the month's dots",
        until: () => Calendar.eventsOn(new Date(2026, 10, 12)).map(event => event.title).join() === "Holiday,Night shift"
          && Calendar.colorsOn(new Date(2026, 10, 12)).join() === "#33b679,#4285f4" && Calendar.colorsOn(new Date(2026, 10, 15)).length === 0
      },
      {
        name: "a timed event's times take one line; one running past its day says when it ends, a middle day all day",
        until: () => [
          times("Standup", new Date(2026, 10, 26)), times("Call", new Date(2026, 10, 25)),
          times("Night shift", new Date(2026, 10, 12)), times("Night shift", new Date(2026, 10, 13)), times("Night shift", new Date(2026, 10, 14)),
          times("Trip", new Date(2026, 10, 20)), times("Trip", new Date(2026, 10, 21))
        ].join() === "09:00–09:15|,09:00|,22:00|to Sat 01:00,All day|to Sat 01:00,to 01:00|,All day|to Sat,All day|"
      },
      {
        name: "a timed event ending a week or more on says its date alone, as wide as the time column holds, and its time in the details",
        until: () => {
          const day = new Date(2026, 10, 23);
          const far = { start: new Date(2026, 10, 23, 9), end: new Date(2026, 10, 30, 18), allDay: false };
          const near = { start: new Date(2026, 10, 23, 9), end: new Date(2026, 10, 28, 18), allDay: false };
          const column = events.times(far, day);
          return column.join("|") === "09:00|to 30 Nov" && events.times(near, day).join("|") === "09:00|to Sat 18:00"
            && column[1].length <= events.timeChars && events.times(far, day, true)[1].endsWith(" 18:00");
        }
      },
      {
        name: "the days the file was synced over are known, so a day past them is not taken for one without events",
        until: () => Calendar.synced(new Date(2026, 10, 12)) && Calendar.synced(new Date(2027, 10, 12))
          && !Calendar.synced(new Date(2027, 10, 13)) && !Calendar.synced(new Date(2026, 8, 10))
      },
      {
        name: "today starts at its first timed event not over yet, another day at its first",
        until: () => {
          const now = Clock.date.getTime();
          const today = Clock.dayKey(Clock.date);
          const rows = [
            { key: "2000-01-01", event: { allDay: false, end: new Date(2000, 0, 1, 10) } },
            { key: today, event: { allDay: true, end: new Date(now + 86400000) } },
            { key: today, event: { allDay: false, end: new Date(now - 60000) } },
            { key: today, event: { allDay: false, end: new Date(now + 3600000) } }
          ];
          return Calendar.firstOn(rows, today) === 3 && Calendar.firstOn(rows, "2000-01-01") === 0 && Calendar.firstOn(rows, "1999-01-01") === 0;
        }
      },
      {
        name: "today's timed events that are over fold into one line where the first was, so its heading and what is next stay in view",
        until: () => {
          const now = Clock.date.getTime();
          const today = Clock.dayKey(Clock.date);
          const rows = [
            { id: "a", key: today, event: { title: "Holiday", allDay: true, end: new Date(now + 86400000) } },
            { id: "b", key: today, event: { title: "Standup", allDay: false, end: new Date(now - 60000) } },
            { id: "c", key: today, event: { title: "Review", allDay: false, end: new Date(now + 3600000) } },
            { id: "d", key: today, event: { title: "Coffee", allDay: false, end: new Date(now - 30000) } },
            { id: "e", key: "2000-01-01", event: { title: "Gym", allDay: false, end: new Date(2000, 0, 1, 10) } }
          ];
          const ids = rows.filter(row => Calendar.earlier(row)).map(row => row.id);
          const shown = events.fold(rows, ids).map(row => row.earlier ? row.earlier.map(event => event.title).join("+") : row.event.title);
          return ids.join() === "b,d" && shown.join() === "Holiday,Standup+Coffee,Review,Gym" && events.fold(rows, []) === rows;
        }
      },
      {
        name: "the keys reaching one of today's events that are over unfold them, and stepping back folds them again",
        until: () => {
          const now = Clock.date.getTime();
          const today = Clock.dayKey(Clock.date);
          menu.viewModels.calendar.select(new Date());
          menu.viewModels.calendar.focus({ id: "next", key: today, day: new Date(), event: { allDay: false, end: new Date(now + 3600000) } });
          const ahead = menu.viewModels.calendar.unfolded;
          menu.viewModels.calendar.focus({ id: "over", key: today, day: new Date(), event: { allDay: false, end: new Date(now - 60000) } });
          menu.viewModels.calendar.focus({ id: "next", key: today, day: new Date(), event: { allDay: false, end: new Date(now + 3600000) } });
          const kept = menu.viewModels.calendar.unfolded;
          menu.viewModels.calendar.stepBack();
          return !ahead && kept && !menu.viewModels.calendar.unfolded;
        }
      },
      {
        name: "on a narrow list the times fold under each title",
        until: () => !events.folded && narrow.folded && events.lineCount(Calendar.timeline[6]) === 1 && narrow.lineCount(Calendar.timeline[6]) === 2
      },
      {
        name: "the events follow the selected day from one day with events to another",
        start: () => events.selected = new Date(2026, 10, 25),
        until: () => events.contentY > 0
      },
      {
        name: "the last day scrolls to the top as any other, under its heading",
        start: () => events.selected = new Date(2026, 10, 26),
        until: () => {
          const item = events.itemAtIndex(events.rows.findIndex(row => row.key === "2026-11-26"));
          return !!item && Math.abs(item.y - events.contentY - events.headingHeight) < 1;
        }
      },
      {
        name: "Return on a focused event shows it whole, its legend then naming Return no more; Escape hides it, then leaves the event",
        until: () => {
          const returns = () => menu.viewModels.calendar.legend.some(key => key.key === "Return");
          menu.viewModels.calendar.select(new Date(2026, 10, 12));
          menu.viewModels.calendar.handleKey("Return");
          const focused = menu.viewModels.calendar.focused !== "" && !menu.viewModels.calendar.details && returns();
          menu.viewModels.calendar.handleKey("Return");
          const shown = menu.viewModels.calendar.details && !returns();
          return focused && shown && menu.viewModels.calendar.stepBack() && !menu.viewModels.calendar.details && menu.viewModels.calendar.focused !== ""
            && menu.viewModels.calendar.stepBack() && menu.viewModels.calendar.focused === "" && !menu.viewModels.calendar.stepBack();
        }
      },
      {
        name: "an event's details take the place of the rows, which hold still, until they close",
        start: () => {
          events.selected = new Date(2026, 10, 12);
          events.focused = Calendar.timeline[1].id;
          events.details = true;
        },
        until: () => events.detailRow?.event.title === "Night shift" && !events.interactive
          && events.rows.every((_, at) => !events.itemAtIndex(at)?.visible)
      },
      {
        name: "closing the details shows the rows again",
        start: () => events.details = false,
        until: () => !events.detailRow && events.interactive && events.itemAtIndex(1)?.visible
      },
      {
        name: "two events alike on one day are told apart by uid, so Down steps from one to the other",
        until: () => {
          const pair = Calendar.timeline.filter(row => row.event.title === "Standup");
          menu.viewModels.calendar.focus(pair[0]);
          menu.viewModels.calendar.handleKey("Down");
          return pair.length === 2 && pair[0].id !== pair[1].id && menu.viewModels.calendar.focused === pair[1].id;
        }
      },
      {
        name: "an event spanning centuries takes a row only on the days synced, and one of a few days one on each",
        // From here on, as they replace the events.
        start: () => write({ synced: { from: "2026-11-01", to: "2026-11-30" }, events: [
          { title: "Ages", start: "1500-01-01", end: "2500-01-01", allDay: true },
          { title: "Night shift", start: "2026-11-12T22:00", end: "2026-11-14T01:00" }
        ] }),
        until: () => rows("Ages").length === 30 && rows("Night shift").map(row => row.key).join() === "2026-11-12,2026-11-13,2026-11-14"
      },
      {
        name: "a file naming no synced days takes them a year either side of today",
        start: () => {
          const today = Clock.date;
          const after = new Date(today.getFullYear(), today.getMonth(), today.getDate() + 2);
          write({ events: [{ title: "Ages", start: "1500-01-01", end: "2500-01-01", allDay: true }, { title: "Trip", start: Clock.dayKey(today), end: Clock.dayKey(after), allDay: true }] });
        },
        until: () => rows("Ages").length > 700 && rows("Ages").length <= 733 && rows("Trip").length === 3
      },
      {
        name: "an event not reminded yet is, and kept",
        // One five minutes on.
        start: () => {
          const start = Clock.minuteKey(new Date(Date.now() + 300000));
          Kept.set("calendar.reminded", []);
          write({ events: [{ uid: "soon", title: "Soon", start, end: start, color: "#4285f4" }] });
        },
        until: () => {
          if (!Calendar.timeline.some(row => row.event.title === "Soon")) return false;
          Calendar.remind();
          reminded.reload();
          return reminded.text().split("\n").includes("Soon") && Array.from(Kept.value("calendar.reminded") ?? []).some(id => id.endsWith(" soon"));
        }
      }
    ]
  }

  // What calendar.remind ran, a line each.
  FileView {
    id: reminded
    path: Quickshell.env("XDG_RUNTIME_DIR") + "/reminded"
    blockLoading: true
    printErrors: false
  }

  // Short enough that the last day is out of view from the first.
  CalendarEvents {
    id: events
    width: 400
    height: 100
    selected: new Date(2026, 10, 12)
  }

  CalendarEvents {
    id: narrow
    width: 150
    height: 100
    selected: new Date(2026, 10, 12)
  }

  MenuModel {
    id: menu
  }
}
