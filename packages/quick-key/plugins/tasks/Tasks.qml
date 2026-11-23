import QtQuick
import qs
import qs.services
import qs.ui

// Tasks from a file (docs/src/tasks.md).
Plugin {
  id: root

  readonly property string today: Clock.dayKey(Clock.date)
  // A timed task is late once its minute has passed.
  readonly property string now: Clock.minuteKey(Clock.date)
  words: ({
    none: "No tasks",
    adding: "Adding" + Words.ellipsis,
    noneDone: "No completed tasks",
    sortedBy: { due: "by due date", priority: "by priority", title: "by title", list: "by list" },
    addFailed: what => "Could not add " + what,
    tickFailed: what => "Could not tick off " + what,
    reopenFailed: what => "Could not reopen " + what
  })
  // In the order chosen, those done as the menu opened last: a tick in the visit keeps its digit, so the same key unticks it. A tick shows before the file has it.
  readonly property var tasks: Array.from(state.tasks ?? []).map(task => task.id in pending ? Object.assign({}, task, { done: pending[task.id] }) : task).sort((a, b) => root.compare(a, b))
  // A task being added shows in the input, as a turn does, so no row moves under the keys until it is listed.
  turn: adding.length > 0 ? { question: adding.join(" · "), text: "", phase: "working", activity: words.adding } : null
  // Kept once the level's actions step them, over a reload or a restart.
  readonly property string sort: keptSort.value ?? settings.sort
  readonly property string completed: keptCompleted.value ?? settings.completed
  // Ticks and adds not in the file yet, and their commands, run one at a time.
  property var pending: ({})
  property var adding: []
  property var queue: []
  // The last tick or add that failed, until the next one or opening: it shows above the file's own error.
  property string failure: ""
  readonly property var due: tasks.filter(task => !task.done && task.due && task.due.slice(0, 10) <= today)
  readonly property var late: due.filter(task => root.isLate(task))
  readonly property var updated: state.updated ? Clock.parse(state.updated) : null
  // Done as the menu opened: hidden for the visit, so a tick made in it stays to untick.
  property var settled: []
  // Reminders fired, by title and due, kept so a restart repeats none; unset before the first check.
  readonly property var reminded: keptReminded.value

  text: ""
  empty: completed === "only" ? words.noneDone : words.none
  actions: ({
    sort: { icon: () => Glyphs.sorts[root.sort] ?? "", detail: () => root.words.sortedBy[root.sort], available: () => true, run: () => Kept.set(root.name + ".sort", root.after(root.settings.sorts, root.sort)) },
    completed: { icon: () => Glyphs.completed[root.completed] ?? "", detail: () => root.completed, available: () => true, run: () => Kept.set(root.name + ".completed", root.after(root.settings.shows, root.completed)) }
  })
  // At most two characters, so the row holds still.
  detail: {
    const count = late.length || due.length;
    return count > 9 ? "9+" : count > 0 ? String(count) : "";
  }
  tone: late.length > 0 ? "warning" : ""
  glyphs: late.length > 0 ? [Glyphs.late] : []
  error: [failure, state.error ?? ""].filter(line => line).join("\n")
  // The most urgent, whatever the order chosen: late first, then by due.
  fields: ({ title: (late.length > 0 ? late : due).slice().sort((a, b) => root.order(a.due, b.due))[0]?.title ?? "", count: detail, updated: updated ? Words.updated(Clock.when(updated, true)) : "" })
  fieldTones: ({ updated: Clock.stale(updated, settings.staleAfter) ? "warning" : "" })
  items: tasks.map(task => {
    const late = root.isLate(task);
    const priority = root.priorityOf(task);
    return {
      id: task.id,
      label: task.title,
      icon: task.done ? Glyphs.checkboxChecked : Glyphs.checkbox,
      glyphs: (priority ? [Glyphs.priorities[priority]] : []).concat(late ? [Glyphs.late] : []),
      // Showing only the done ones, when each was done.
      detail: root.completed === "only" && task.done && task.completed ? Clock.recent(Clock.parse(task.completed))
        : task.due ? Clock.when(Clock.parse(task.due), task.due.includes("T")) : "",
      swatch: task.color ?? "",
      done: !!task.done,
      hidden: root.completed === "hidden" ? !!task.done && root.settled.includes(task.id) : root.completed === "only" && !task.done && !root.settled.includes(task.id),
      tone: late ? "warning" : "",
      verb: task.done ? "untick" : "tick"
    };
  })

  // Dates by code point: a locale may sort the undated mark (~) before digits.
  function order(a, b) {
    return a < b ? -1 : a > b ? 1 : 0;
  }

  function isLate(task) {
    return !task.done && !!task.due && (task.due.includes("T") ? task.due < now : task.due < today);
  }

  // As iCalendar ranks them: 1 to 4 high, 5 medium, 6 to 9 low; unset or 0, none.
  function priorityOf(task) {
    const rank = task.priority ?? 0;
    return rank <= 0 ? "" : rank < 5 ? "high" : rank === 5 ? "medium" : "low";
  }

  // Those done as the menu opened after the rest, then by the order chosen, then by due (undated last), then by title; priority 1 first, none last.
  function compare(a, b) {
    const done = settled.includes(a.id) - settled.includes(b.id);
    if (done) return done;
    const due = order(a.due ?? "~", b.due ?? "~");
    const title = a.title.localeCompare(b.title);
    const rank = task => task.priority > 0 ? task.priority : 10;
    if (sort === "title") return title || due;
    if (sort === "priority") return rank(a) - rank(b) || due || title;
    if (sort === "list") return order(a.list ?? "", b.list ?? "") || due || title;
    return due || title;
  }

  function after(cycle, current) {
    return cycle[(cycle.indexOf(current) + 1) % cycle.length];
  }

  // A tick shows at once; its command waits its turn, as each holds the calendar's lock and a sync may hold it too.
  function select(id) {
    const task = tasks.find(task => task.id === id);
    if (!task) return;
    failure = "";
    pending = Object.assign({}, pending, { [id]: !task.done });
    queue = queue.concat([{ verb: task.done ? "reopen" : "done", arg: id, title: task.title }]);
    next();
  }

  // Shows at once, dim until the file has it.
  function submit(text, after) {
    failure = "";
    adding = adding.concat([text]);
    queue = queue.concat([{ verb: "add", arg: text, after: after }]);
    next();
  }

  function next() {
    if (toggler.running || queue.length === 0) return;
    toggler.job = queue[0];
    queue = queue.slice(1);
    // An unset command fails, as `false`: given none, the line would run its first argument, a task's id or title.
    toggler.command = commandLine(settings[toggler.job.verb] || "false", toggler.job.arg, ...("title" in toggler.job ? [toggler.job.title] : []));
    toggler.running = true;
  }

  // The file has a tick once it says the same, and an added task once it holds its title: neither needs showing on its own then.
  onStateChanged: {
    pending = kept((id, done) => Array.from(state.tasks ?? []).find(task => task.id === id)?.done !== done);
    adding = adding.filter(title => !Array.from(state.tasks ?? []).some(task => task.title === title));
    // Once `tasks` has the change: a task the file adds already due reminds without waiting for the minute.
    Qt.callLater(root.remind);
  }

  function kept(test) {
    return Object.keys(pending).reduce((kept, id) => test(id, pending[id]) ? Object.assign(kept, { [id]: pending[id] }) : kept, {});
  }

  // As the menu opens, a sync when the file is old (syncAfter), and what is done by then hides; a failed tick is old news by then.
  function refresh() {
    failure = "";
    settled = tasks.filter(task => task.done).map(task => task.id);
    if (!updated || Clock.stale(updated, settings.syncAfter)) exec(settings.sync);
  }

  // Each open timed task once it falls due, however late the check comes (a suspend, the shell off); the first check fires only this minute's, not every late one.
  function remind() {
    if (!settings.remind || !state.tasks) return;
    const key = task => task.title + " " + task.due;
    const timed = tasks.filter(task => task.due?.includes("T"));
    // Those the file no longer lists are forgotten.
    const fired = Array.from(reminded ?? []).filter(fired => timed.some(task => key(task) === fired));
    for (const task of timed) {
      if (task.done || task.due > now || fired.includes(key(task))) continue;
      fired.push(key(task));
      if (reminded || task.due === now) exec(settings.remind, task.title, Clock.time(Clock.parse(task.due)));
    }
    if (!reminded || fired.join("\n") !== Array.from(reminded).join("\n")) Kept.set(name + ".reminded", fired);
  }

  KeptValue {
    id: keptSort
    key: root.name + ".sort"
  }

  KeptValue {
    id: keptCompleted
    key: root.name + ".completed"
  }

  KeptValue {
    id: keptReminded
    key: root.name + ".reminded"
  }

  Connections {
    target: Clock

    function onDateChanged() {
      root.remind();
    }
  }

  // A tick whose command is done but the file never says so is dropped, the file's state shown again.
  Timer {
    id: settle
    interval: 5000
    onTriggered: root.pending = root.kept(id => root.queue.some(job => job.arg === id) || toggler.running && toggler.job.arg === id)
  }

  // Each tick and add written in turn; the sync after the last takes them to the server.
  CommandProcess {
    id: toggler
    // { verb, arg, title, after }: done or reopen, an id and its title, or add and a title, then what runs once it is added.
    property var job: null
    onExited: code => {
      // An add is over as its command is, whatever title the file gave it (a command may read a date out of it).
      if (job.verb === "add") root.adding = root.adding.filter(title => title !== job.arg);
      if (code === 0) {
        root.exec(job.after);
        settle.restart();
      }
      if (code !== 0 && job.verb === "add") {
        root.failure = root.words.addFailed(job.arg);
      } else if (code !== 0) {
        root.pending = root.kept(id => id !== job.arg);
        root.failure = (job.verb === "done" ? root.words.tickFailed : root.words.reopenFailed)(job.title);
      }
      if (root.queue.length > 0) root.next();
      else root.exec(root.settings.sync);
    }
  }
}
