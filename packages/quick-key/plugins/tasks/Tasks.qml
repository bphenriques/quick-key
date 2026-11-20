import QtQuick
import Quickshell.Io
import qs
import qs.services
import qs.ui

// Tasks from a file (docs/src/tasks.md): how many are due by today as its status, each on a digit to tick and untick, and the level's input to add one.
Plugin {
  id: root

  readonly property string today: Clock.dayKey(Clock.date)
  // By due, undated last, never by whether done: a tick keeps its digit, so the same key unticks it. A tick shows before the file has it, and an added task last, so no digit moves until the file places it.
  readonly property var tasks: Array.from(state.tasks ?? []).map(task => task.id in pending ? Object.assign({}, task, { done: pending[task.id] }) : task)
    .sort((a, b) => root.order(a.due ?? "~", b.due ?? "~") || a.title.localeCompare(b.title))
    .concat(adding.map(title => ({ id: "", title, adding: true })))
  // Ticks not in the file yet, by id: done or not; titles added and not in it yet; and their commands, run one at a time.
  property var pending: ({})
  property var adding: []
  property var queue: []
  // The last tick or add that failed, until the next one or opening: it shows above the file's own error.
  property string failure: ""
  // Open and due by today, late first.
  readonly property var due: tasks.filter(task => !task.done && task.due && task.due.slice(0, 10) <= today)
  readonly property var late: due.filter(task => task.due.slice(0, 10) < today)
  // Done as the menu opened: hidden for the visit, so a tick made in it stays to untick.
  property var settled: []
  // The tasks reminded of, by id and due, so each is once.
  property var reminded: ({})

  glyph: settings.glyph
  text: ""
  empty: "No tasks"
  // How many are late, beside the alarm, else how many are due by today; two characters at most, so the row holds still.
  detail: {
    const count = late.length || due.length;
    return count > 9 ? "9+" : count > 0 ? String(count) : "";
  }
  tone: late.length > 0 ? "warning" : ""
  glyphs: late.length > 0 ? [Glyphs.late] : []
  error: [failure, state.error ?? ""].filter(line => line).join("\n")
  fields: ({ title: due.length > 0 ? due[0].title : "", count: detail, updated: state.updated ? "updated " + Clock.when(Clock.parse(state.updated), true) : "" })
  fieldTones: ({ updated: state.updated && Clock.date - Clock.parse(state.updated) >= settings.staleAfter * 60000 ? "warning" : "" })
  items: tasks.map(task => {
    const late = !task.done && !!task.due && task.due.slice(0, 10) < today;
    return {
      id: task.id,
      label: task.title,
      icon: task.done ? Glyphs.checkboxChecked : Glyphs.checkbox,
      glyphs: late ? [Glyphs.late] : [],
      detail: task.due ? Clock.when(Clock.parse(task.due), task.due.includes("T")) : "",
      done: !!task.done,
      hidden: !!task.done && root.settled.includes(task.id),
      busy: !!task.adding,
      enabled: !task.adding,
      tone: late ? "warning" : "",
      verb: task.done ? "untick" : "tick"
    };
  })

  // Dates by code point: a locale may sort the undated mark (~) before digits.
  function order(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
  }

  // A tick shows at once; its command waits its turn, as each holds the calendar's lock and a sync may hold it too.
  function select(id) {
    const task = tasks.find(task => task.id === id);
    if (!task || task.adding) return;
    failure = "";
    pending = Object.assign({}, pending, { [id]: !task.done });
    queue = queue.concat([{ verb: task.done ? "reopen" : "done", arg: id }]);
    next();
  }

  // An added task shows at once, dim until the file has it; its command waits its turn as a tick does.
  function submit(text, background, after) {
    failure = "";
    adding = adding.concat([text]);
    queue = queue.concat([{ verb: "add", arg: text, after: after }]);
    next();
  }

  function next() {
    if (toggler.running || queue.length === 0) return;
    toggler.job = queue[0];
    queue = queue.slice(1);
    toggler.command = commandLine(settings[toggler.job.verb], toggler.job.arg);
    toggler.running = true;
  }

  // The file has a tick once it says the same, and an added task once it holds its title: neither needs showing on its own then.
  onStateChanged: {
    pending = kept((id, done) => Array.from(state.tasks ?? []).find(task => task.id === id)?.done !== done);
    adding = adding.filter(title => !Array.from(state.tasks ?? []).some(task => task.title === title));
  }

  // The pending ticks that pass a test, by id and done.
  function kept(test) {
    return Object.keys(pending).reduce((kept, id) => test(id, pending[id]) ? Object.assign(kept, { [id]: pending[id] }) : kept, {});
  }

  // As the menu opens, a sync when the file is old (syncAfter), and what is done by then hides; a failed tick is old news by then.
  function refresh() {
    failure = "";
    settled = tasks.filter(task => task.done).map(task => task.id);
    if (!state.updated || Clock.date - Clock.parse(state.updated) >= settings.syncAfter * 60000) exec(settings.sync);
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

  // Each tick and add is written to the file in turn; a failed one shows the file's state again. The sync after the last takes them to the server.
  Process {
    id: toggler
    // { verb, arg, after }: done or reopen and an id, or add and a title, then what runs once it is added.
    property var job: null
    onExited: code => {
      // An add is over as its command is, whatever title the file gave it (a command may read a date out of it).
      if (job.verb === "add") root.adding = root.adding.filter(title => title !== job.arg);
      if (code === 0) root.exec(job.after);
      if (code !== 0 && job.verb === "add") {
        root.failure = "Could not add " + job.arg;
      } else if (code !== 0) {
        root.pending = root.kept(id => id !== job.arg);
        root.failure = (job.verb === "done" ? "Could not tick off " : "Could not reopen ") + (Array.from(root.state.tasks ?? []).find(task => task.id === job.arg)?.title ?? job.arg);
      }
      if (root.queue.length > 0) root.next();
      else root.exec(root.settings.sync);
    }
  }
}
