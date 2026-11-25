import QtQuick
import Quickshell
import Quickshell.Io
import qs
import qs.services
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

  Suite {
    id: suite
    cases: [
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
        name: "the keys reaching one of today's events that are over unfold them, and stepping back folds them again",
        until: () => {
          const now = Clock.date.getTime();
          const today = Clock.dayKey(Clock.date);
          calendar.select(new Date());
          calendar.focus({ id: "next", key: today, day: new Date(), event: { allDay: false, end: new Date(now + 3600000) } });
          const ahead = calendar.unfolded;
          calendar.focus({ id: "over", key: today, day: new Date(), event: { allDay: false, end: new Date(now - 60000) } });
          calendar.focus({ id: "next", key: today, day: new Date(), event: { allDay: false, end: new Date(now + 3600000) } });
          const kept = calendar.unfolded;
          calendar.stepBack();
          return !ahead && kept && !calendar.unfolded;
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
        name: "after the width changes, a day's heading shows only with its first row whole under it",
        start: () => widened.width = 400,
        until: () => {
          // Headings are the list's items with a section; each holds the heading that hides.
          const headings = Array.from(widened.contentItem.children).filter(item => item.section !== undefined && item.children[0]?.visible);
          const first = heading => widened.itemAtIndex(widened.rows.findIndex(row => row.key === heading.section));
          return !widened.folded && headings.length > 1 && headings.every(heading => first(heading)?.visible);
        }
      },
      {
        name: "Return on a focused event shows it whole, its legend then naming Return no more; Escape hides it, then leaves the event",
        until: () => {
          const returns = () => calendar.legend.some(key => key.key === "Return");
          calendar.select(new Date(2026, 10, 12));
          calendar.handleKey("Return");
          const focused = calendar.focused !== "" && !calendar.details && returns();
          calendar.handleKey("Return");
          const shown = calendar.details && !returns();
          return focused && shown && calendar.stepBack() && !calendar.details && calendar.focused !== ""
            && calendar.stepBack() && calendar.focused === "" && !calendar.stepBack();
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
          calendar.focus(pair[0]);
          calendar.handleKey("Down");
          return pair.length === 2 && pair[0].id !== pair[1].id && calendar.focused === pair[1].id;
        }
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

  // Narrow, then widened as the level lays it out: its rows' times fold, then unfold.
  CalendarEvents {
    id: widened
    width: 150
    height: 260
    selected: new Date(2026, 10, 12)
  }

  CalendarModel {
    id: calendar
  }
}
