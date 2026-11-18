import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Tasks from a file (docs/src/tasks.md): how many are due by today as its status, each on a digit to tick and untick.
Plugin {
  id: root

  readonly property string today: Clock.dayKey(Clock.date)
  // By due, undated last, never by whether done: a tick keeps its digit, so the same key unticks it. A tick shows before the file has it.
  readonly property var tasks: Array.from(state.tasks ?? []).map(task => task.id in pending ? Object.assign({}, task, { done: pending[task.id] }) : task)
    .sort((a, b) => root.order(a.due ?? "~", b.due ?? "~") || a.title.localeCompare(b.title))
  // Ticks not in the file yet, by id: done or not; and their commands, run one at a time.
  property var pending: ({})
  property var queue: []
  // The last tick that failed, until the next tick: it shows above the file's own error.
  property string failure: ""
  // Open and due by today, late first.
  readonly property var due: tasks.filter(task => !task.done && task.due && task.due.slice(0, 10) <= today)
  // The tasks reminded of, by id and due, so each is once.
  property var reminded: ({})

  glyph: settings.glyph
  text: ""
  // Two characters at most, so the row holds still.
  detail: due.length > 9 ? "9+" : due.length > 0 ? String(due.length) : ""
  tone: due.length > 0 && due[0].due.slice(0, 10) < today ? "warning" : ""
  error: [failure, state.error ?? ""].filter(line => line).join("\n")
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

  // A tick shows at once; its command waits its turn, as each holds the calendar's lock and a sync may hold it too.
  function select(id) {
    const task = tasks.find(task => task.id === id);
    if (!task) return;
    failure = "";
    pending = Object.assign({}, pending, { [id]: !task.done });
    queue = queue.concat([{ id, done: !task.done }]);
    next();
  }

  function next() {
    if (toggler.running || queue.length === 0) return;
    toggler.tick = queue[0];
    queue = queue.slice(1);
    toggler.command = commandLine(toggler.tick.done ? settings.done : settings.reopen, toggler.tick.id);
    toggler.running = true;
  }

  // The file has a tick once it says the same: it no longer needs showing on its own.
  onStateChanged: pending = kept((id, done) => Array.from(state.tasks ?? []).find(task => task.id === id)?.done !== done)

  // The pending ticks that pass a test, by id and done.
  function kept(test) {
    return Object.keys(pending).reduce((kept, id) => test(id, pending[id]) ? Object.assign(kept, { [id]: pending[id] }) : kept, {});
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

  // Each tick is written to the file in turn; a failed one shows the file's state again. The sync after the last takes them to the server.
  Process {
    id: toggler
    property var tick: null
    onExited: code => {
      if (code !== 0) {
        root.pending = root.kept(id => id !== tick.id);
        root.failure = (tick.done ? "Could not tick off " : "Could not reopen ") + (Array.from(root.state.tasks ?? []).find(task => task.id === tick.id)?.title ?? tick.id);
      }
      if (root.queue.length > 0) root.next();
      else root.exec(root.settings.sync);
    }
  }
}
