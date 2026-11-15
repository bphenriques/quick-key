import QtQuick
import Quickshell
import qs.services
import qs.widgets.menu

// The calendar's dates and the events it shows on them; the events are events.json's, around 12 November 2026.
ShellRoot {
  Suite {
    cases: [
      {
        name: "a month or year away keeps the day, or the month's last when it has fewer",
        until: () => [[new Date(2027, 0, 31), [0, 1, 0]], [new Date(2028, 1, 29), [1, 0, 0]], [new Date(2026, 11, 31), [0, 0, 1]]].map(([from, move]) => {
          menu.calendar.selected = from;
          menu.calendar.moveSelected(...move);
          return Calendar.key(menu.calendar.selected);
        }).join() === "2027-02-28,2029-02-28,2027-01-01"
      },
      {
        name: "an event shows on every day it overlaps, all-day ones first",
        until: () => Calendar.timeline.map(row => row.key.slice(8) + " " + row.event.title).join() ===
          "12 Holiday,12 Night shift,13 Night shift,14 Night shift,20 Trip,21 Trip,25 Call"
      }
    ]
  }

  MenuModel {
    id: menu
  }
}
