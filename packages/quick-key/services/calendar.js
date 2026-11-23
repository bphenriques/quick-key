.pragma library

// The calendar's decisions, pure: each takes `now`, so a unit test fixes it (tests/unit).

// Each timed event once, `before` minutes ahead: those to remind at `now`, and every one fired by id (`reminded`) still to come.
function due(events, reminded, now, before) {
  const until = new Date(now.getTime() + before * 60000);
  const fired = reminded.filter(id => events.some(event => event.id === id && event.start > now));
  const remind = [];
  for (const event of events) {
    if (event.allDay || event.start <= now || event.start > until || fired.includes(event.id)) continue;
    fired.push(event.id);
    remind.push(event);
  }
  return { remind, fired };
}
