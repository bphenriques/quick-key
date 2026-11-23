import QtQuick
import QtTest
import "tasks.js" as Tasks

// The tasks' order, lateness and reminders, at a fixed minute (25 November 2026, 14:00).
TestCase {
  name: "tasks"

  readonly property string now: "2026-11-25T14:00"
  readonly property string today: "2026-11-25"

  // A timed task is late once its minute has passed, today too; one due today without a time only from tomorrow.
  function test_isLate() {
    verify(Tasks.isLate({ due: "2026-11-25T13:59" }, now, today));
    verify(!Tasks.isLate({ due: now }, now, today));
    verify(!Tasks.isLate({ due: today }, now, today));
    verify(Tasks.isLate({ due: "2026-11-24" }, now, today));
    verify(!Tasks.isLate({ due: "2026-11-25T13:59", done: true }, now, today));
    verify(!Tasks.isLate({}, now, today));
  }

  function test_priorityOf() {
    compare([0, 1, 4, 5, 6, 9].map(priority => Tasks.priorityOf({ priority })).concat(Tasks.priorityOf({})), ["", "high", "high", "medium", "low", "low", ""]);
  }

  // Those settled after the rest, then by the order chosen, then by due (undated last), then by title; priority 1 first, none last.
  function test_compare() {
    const tasks = [
      { id: "d", title: "Undated", list: "home" },
      { id: "c", title: "Later", list: "work", due: "2026-11-26" },
      { id: "b", title: "Now", list: "home", priority: 1, due: now },
      { id: "a", title: "Late", list: "work", priority: 5, due: "2026-11-24" },
      { id: "e", title: "Ticked", list: "home", due: "2026-11-24" },
      { id: "f", title: "Today", list: "home", due: today }
    ];
    const sorted = (sort, settled) => tasks.slice().sort((a, b) => Tasks.compare(a, b, sort, settled)).map(task => task.id).join();
    compare(sorted("due", []), "a,e,f,b,c,d");
    compare(sorted("due", ["e"]), "a,f,b,c,d,e");
    compare(sorted("priority", ["e"]), "b,a,f,c,d,e");
    compare(sorted("title", ["e"]), "a,c,b,f,d,e");
    compare(sorted("list", ["e"]), "f,b,d,a,c,e");
  }

  // Once each as it falls due, however late the check; a first check, none fired yet, reminds only this minute's and keeps the rest as fired.
  function test_due() {
    const tasks = [
      { title: "Now", due: now },
      { title: "Missed", due: "2026-11-25T13:55" },
      { title: "Soon", due: "2026-11-25T14:05" },
      { title: "Done", due: "2026-11-25T13:00", done: true },
      { title: "Undated" },
      { title: "Today", due: today }
    ];
    const first = Tasks.due(tasks, undefined, now);
    compare(first.remind.map(task => task.title), ["Now"]);
    compare(first.fired, ["Now " + now, "Missed 2026-11-25T13:55"]);
    const unseen = Tasks.due(tasks, [], now);
    compare(unseen.remind.map(task => task.title), ["Now", "Missed"]);
    const again = Tasks.due(tasks, unseen.fired, now);
    compare(again.remind, []);
    compare(again.fired, unseen.fired);
    // One the file no longer lists is forgotten.
    compare(Tasks.due(tasks.slice(1), unseen.fired, now).fired, ["Missed 2026-11-25T13:55"]);
  }
}
