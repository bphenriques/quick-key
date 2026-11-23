import QtQuick
import Quickshell
import qs.services
import qs.widgets.menu
import qs.widgets.menu.calendar

// The calendar's dates and the events it shows on them; the events are events.json's, around 12 November 2026.
ShellRoot {
  Suite {
    cases: [
      {
        name: "a month or year away keeps the day, or the month's last when it has fewer",
        until: () => [[new Date(2027, 0, 31), [0, 1, 0]], [new Date(2028, 1, 29), [1, 0, 0]], [new Date(2026, 11, 31), [0, 0, 1]]].map(([from, move]) => {
          menu.calendar.select(from);
          menu.calendar.moveSelected(...move);
          return Clock.dayKey(menu.calendar.selected);
        }).join() === "2027-02-28,2029-02-28,2027-01-01"
      },
      {
        name: "an event shows on every day it overlaps, all-day ones first",
        until: () => Calendar.timeline.map(row => row.key.slice(8) + " " + row.event.title).join() ===
          "12 Holiday,12 Night shift,13 Night shift,14 Night shift,20 Trip,21 Trip,25 Call"
      },
      {
        name: "a day gives its events and their colours, each once, for the month's dots",
        until: () => Calendar.eventsOn(new Date(2026, 10, 12)).map(event => event.title).join() === "Holiday,Night shift"
          && Calendar.colorsOn(new Date(2026, 10, 12)).join() === "#33b679,#4285f4" && Calendar.colorsOn(new Date(2026, 10, 15)).length === 0
      },
      {
        name: "the events follow the selected day from one day with events to another",
        start: () => events.selected = new Date(2026, 10, 25),
        until: () => events.contentY > 0
      }
    ]
  }

  // Short enough that the last day is out of view from the first.
  CalendarEvents {
    id: events
    width: 400
    height: 100
    selected: new Date(2026, 10, 12)
  }

  MenuModel {
    id: menu
  }
}
