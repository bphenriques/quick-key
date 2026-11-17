import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Tasks from a file (docs/src/tasks.md): how many are due by today as its status, each on a digit to tick and untick.
Plugin {
  id: root

  readonly property string today: Clock.dayKey(Clock.date)
  // By due, undated last, never by whether done: a tick keeps its digit, so the same key unticks it.
  readonly property var tasks: Array.from(state.tasks ?? []).sort((a, b) => root.order(a.due ?? "~", b.due ?? "~") || a.title.localeCompare(b.title))
  // Open and due by today, late first.
  readonly property var due: tasks.filter(task => !task.done && task.due && task.due.slice(0, 10) <= today)
  // The tasks reminded of, by id and due, so each is once.
  property var reminded: ({})

  glyph: settings.glyph
  text: ""
  // Two characters at most, so the row holds still.
  detail: due.length > 9 ? "9+" : due.length > 0 ? String(due.length) : ""
  tone: due.length > 0 && due[0].due.slice(0, 10) < today ? "warning" : ""
  fields: ({ title: due.length > 0 ? due[0].title : "", count: detail, updated: state.updated ? "updated " + Clock.stamp(Clock.parse(state.updated)) : "" })
  items: tasks.map(task => ({ id: task.id, label: task.title, icon: task.done ? Glyphs.checkboxChecked : Glyphs.checkbox, detail: when(task.due), done: !!task.done, tone: !task.done && task.due && task.due.slice(0, 10) < today ? "warning" : "" }))

  // Dates by code point: a locale may sort the undated mark (~) before digits.
  function order(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
  }

  // Its time when today, else its day, and the time when it has one.
  function when(due) {
    if (!due) return "";
    const time = due.includes("T");
    if (due.slice(0, 10) === today) return time ? due.slice(11) : "today";
    return Clock.format(Clock.parse(due), time ? "%-d %b %H:%M" : "%-d %b");
  }

  // A pick while the last one runs is dropped: the file shows the outcome before another makes sense.
  function select(id) {
    const task = tasks.find(task => task.id === id);
    if (!task || toggler.running) return;
    toggler.command = commandLine(task.done ? settings.reopen : settings.done, id);
    toggler.running = true;
  }

  // As the menu opens, a sync when the file is five minutes old: one on every opening would keep the calendar syncing too.
  function refresh() {
    if (!state.updated || Clock.date - Clock.parse(state.updated) >= 5 * 60000) exec(settings.sync);
  }

  // Each timed task once, as its time comes, on the clock's own minute.
  function remind() {
    if (!settings.remind) return;
    const now = Clock.date;
    for (const task of tasks) {
      if (task.done || !task.due || !task.due.includes("T")) continue;
      const due = Clock.parse(task.due);
      const key = task.id + " " + task.due;
      if (due > now || now - due >= 60000 || reminded[key]) continue;
      reminded[key] = true;
      exec(settings.remind, task.title, task.due.slice(11));
    }
  }

  Connections {
    target: Clock

    function onDateChanged() {
      root.remind();
    }
  }

  // The tick is written to the file at once; the sync after takes it to the server.
  Process {
    id: toggler
    onExited: root.exec(root.settings.sync)
  }
}
