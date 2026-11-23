.pragma library

// The tasks' order, lateness and reminders, pure: `now` and `today` the minute and the day as the file keys them (Clock.minuteKey, Clock.dayKey), so a unit test fixes them (tests/unit).

// Dates by code point: a locale may sort the undated mark (~) before digits.
function order(a, b) {
  return a < b ? -1 : a > b ? 1 : 0;
}

// A timed task is late once its minute has passed, one without a time from the day after.
function isLate(task, now, today) {
  return !task.done && !!task.due && (task.due.includes("T") ? task.due < now : task.due < today);
}

// As iCalendar ranks them: 1 to 4 high, 5 medium, 6 to 9 low; unset or 0, none.
function priorityOf(task) {
  const rank = task.priority ?? 0;
  return rank <= 0 ? "" : rank < 5 ? "high" : rank === 5 ? "medium" : "low";
}

// Those `settled` (done as the menu opened) after the rest, then by `sort`, then by due (undated last), then by title; priority 1 first, none last.
function compare(a, b, sort, settled) {
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

// Each open timed task once it falls due, however late the check comes (a suspend, the shell off): those to remind, and every one `fired` by title and due, those no longer listed forgotten. With none fired yet (`reminded` unset), only this minute's reminds.
function due(tasks, reminded, now) {
  const key = task => task.title + " " + task.due;
  const timed = tasks.filter(task => task.due && task.due.includes("T"));
  const fired = Array.from(reminded ?? []).filter(each => timed.some(task => key(task) === each));
  const remind = [];
  for (const task of timed) {
    if (task.done || task.due > now || fired.includes(key(task))) continue;
    fired.push(key(task));
    if (reminded || task.due === now) remind.push(task);
  }
  return { remind, fired };
}
