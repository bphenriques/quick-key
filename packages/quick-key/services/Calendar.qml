pragma Singleton

import QtQuick
import Quickshell
import Quickshell.Io
import qs
import "calendar.js" as Lib

// Events from Config.calendar.file (docs/src/calendar.md), read again whenever the file is replaced.
Singleton {
  id: root

  // Whether the file has been read; until then the month shows alone.
  readonly property bool enabled: store.loaded
  readonly property var updated: store.updated
  // Whether a sync is running, and why the last one failed ("" when it did not): the file's own word.
  readonly property bool syncing: store.syncing
  readonly property string error: store.error
  // Each event once per day it falls on, in order: { id, key, day, event }, `id` the same across reads of the file.
  readonly property var timeline: store.timeline
  // The next event not over yet, timed ones first: an all-day one (a daily habit) would otherwise hold it every day.
  readonly property var next: store.events.find(event => !event.allDay && event.end > Clock.date)
    ?? store.events.find(event => event.end > Clock.date) ?? null

  // The events on a day, all-day first, then by start.
  function eventsOn(day) {
    return store.days[Clock.dayKey(day)] ?? [];
  }

  function colorsOn(day) {
    return [...new Set(eventsOn(day).map(event => event.color))];
  }

  // Whether the file covers a day, by the range it was synced over; a file that names none covers every day.
  function synced(day) {
    const key = Clock.dayKey(day);
    return !store.synced || key >= store.synced.from && key <= store.synced.to;
  }

  // As calendar.js has them, from the clock's minute.
  function firstOn(rows, key) {
    return Lib.firstOn(rows, key, Clock.date);
  }

  function earlier(row) {
    return Lib.earlier(row, Clock.date);
  }

  // The list's rows from the day of `key`, those of `ids` folded.
  function rowsFrom(key, ids) {
    return Lib.rows(timeline, key, ids);
  }

  QtObject {
    id: store

    property bool loaded: false
    property var updated: null
    property bool syncing: false
    property string error: ""
    // { from, to }, the first and last day synced, as the file keys them; null when it says none.
    property var synced: null
    property var events: []
    property var days: ({})
    property var timeline: []
    // Read for its change, which checks the reminders: a Connections to Clock fails qmllint once calendar.js imports clock.js.
    readonly property date minute: Clock.date
    onMinuteChanged: root.remind()

    function read(json) {
      const read = Lib.timeline(json, Clock.date);
      events = read.events;
      synced = read.synced;
      days = read.days;
      timeline = read.rows;
      updated = json.updated ? Clock.parse(json.updated) : null;
      syncing = !!json.syncing;
      error = json.error ?? "";
      loaded = true;
    }

    function clear() {
      events = [];
      days = {};
      timeline = [];
      updated = null;
      syncing = false;
      error = "";
      synced = null;
      loaded = false;
    }
  }

  // On the clock's own minute; kept by id, so a restart repeats none.
  function remind() {
    if (!Config.calendar.remind || !store.loaded) return;
    const kept = Array.from(Kept.value("calendar.reminded") ?? []);
    const found = Lib.due(store.events, kept, Clock.date, Config.calendar.remindBefore);
    for (const event of found.remind) Commands.run(Config.calendar.remind, event.title, Clock.time(event.start) + (event.location ? " · " + event.location : ""));
    if (found.fired.join("\n") !== kept.join("\n")) Kept.set("calendar.reminded", found.fired);
  }

  FileView {
    path: Config.calendar.file
    watchChanges: true
    printErrors: false
    onFileChanged: reload()
    onLoaded: {
      try {
        store.read(JSON.parse(text()));
      } catch (error) {
        // A file that cannot be read keeps what was shown.
        console.warn("calendar:", Config.calendar.file + ":", error);
      }
    }
    onLoadFailed: store.clear()
  }
}
