# calendar-sync offline: the todoman fields it reads, the tasks file from a synced folder written as the iPhone writes, then a tick, an untick, a repeating task's and an added task there; then a whole sync of events from a calendar served on loopback, and one whose server is gone.
{ pkgs, self }:
pkgs.runCommand "quick-key-calendar-sync"
  {
    nativeBuildInputs = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key-calendar-sync
      pkgs.jq
      pkgs.python3
      pkgs.todoman
    ];
    TZDIR = "${pkgs.tzdata}/share/zoneinfo";
  }
  ''
    # Set here, as the build resets it: October in Paris is summer time, which a conversion with November's offset gets an hour wrong.
    export HOME=$TMPDIR TZ=Europe/Lisbon
    mkdir -p state/vdirs
    cp -r ${./personal} state/vdirs/personal
    chmod -R u+w state
    sync() { quick-key-calendar-sync "$@" ${./calendars.yaml} state/events.json; }
    tick() { quick-key-calendar-sync "$1" ${./calendars.yaml} state/events.json "$2" "$3"; }
    todo() { PYTHONDONTWRITEBYTECODE=1 command todo --config state/todoman.py --porcelain "$@"; }
    task() { jq -c '.tasks[] | select(.title == "Pay the bills")' state/tasks.json; }
    fail() { echo "not ok - $1"; cat state/tasks.json; exit 1; }
    # A file's lines unfolded, but for the three a tick sets: a tick changes only those.
    others() { sed -z 's/\r\?\n[ \t]//g' "$1" | grep -avE '^(STATUS|COMPLETED|PERCENT-COMPLETE)[:;]'; }
    completed() { [ "$(tr -d '\r' < "$1" | grep -cxE 'STATUS:COMPLETED|COMPLETED:[0-9]{8}T[0-9]{6}Z|PERCENT-COMPLETE:100')" = 3 ]; }

    sync tasks
    # The porcelain fields the script reads, so a todoman that changes them fails here rather than writing a wrong tasks file.
    todo list --status ANY | jq -e 'length == 3 and all(.[]; ([.id, .summary, .list, .completed, .recurring] | map(type)) == ["number", "string", "string", "boolean", "boolean"]
      and has("due") and has("completed_at") and has("priority") and all(.due, .completed_at, .priority; type == "number" or type == "null"))' > /dev/null \
      || fail "todoman's porcelain list gives id, summary, list, completed, recurring, due, completed_at and priority as the script reads them"
    jq -e 'has("updated") | not' state/tasks.json > /dev/null || fail "a tasks file never synced says no sync"
    [ "$(jq '.tasks | length' state/tasks.json)" = 2 ] || fail "a task done more than 14 days ago is left out"
    [ "$(task | jq -c '[.due, .done, .list, .priority, .color]')" = '["2026-10-06T09:00",false,"personal",1,"#ff8c00"]' ] || fail "a task reads with its local time, open, with its list, priority and calendar's colour"

    id=$(task | jq -r .id)
    tick done "$id" "Pay the bills"
    [ "$(task | jq .done)" = true ] || fail "done ticks it off in the tasks file"
    task | jq -r .completed | grep -q "^$(date +%Y-%m-%d)" || fail "done says when, so the done ones can be shown"
    diff <(others ${./personal/bills.ics}) <(others state/vdirs/personal/bills.ics) && completed state/vdirs/personal/bills.ics \
      || fail "done marks the file completed, every other line as it was, a start not before the due date included"
    ! grep -qv $'\r$' state/vdirs/personal/bills.ics || fail "done keeps a file's line endings"
    [ -e state/changed ] || fail "a tick leaves word for a running sync to sync again"
    ! tick done "$(task | jq -r .id)" "Pay the bills" 2> err && grep -q "tasks changed, try again" err || fail "a done of a task done already fails, as its id may since name another alike"

    # todoman numbers a task anew once its file changes outside it, as a tick's does: an id from before may name another task.
    id=$(task | jq -r .id)
    tick reopen "$id" "Pay the bills"
    [ "$(task | jq .done)" = false ] || fail "reopen unticks it in the tasks file"
    grep -q '^STATUS:NEEDS-ACTION' state/vdirs/personal/bills.ics || fail "reopen marks the file as needing action"
    ! grep -qE '^(COMPLETED|PERCENT-COMPLETE)' state/vdirs/personal/bills.ics || fail "reopen drops the record of completion"
    grep -q '^BEGIN:VALARM' state/vdirs/personal/bills.ics || fail "reopen keeps the reminder"
    id=$(task | jq -r .id)
    ! tick done "$id" "Water the plants" 2> err || fail "a tick whose id has another title fails"
    grep -q "tasks changed, try again" err && [ "$(task | jq .done)" = false ] || fail "a tick whose id has another title says so, touching no task"

    water() { jq -c '[.tasks[] | select(.title == "Water the plants")] | sort_by(.due) | map([.due, .done])' state/tasks.json; }
    id=$(jq -r '.tasks[] | select(.title == "Water the plants") | .id' state/tasks.json)
    tick done "$id" "Water the plants"
    [ "$(water)" = '[["2026-11-20",true],["2026-11-27",false]]' ] || fail "ticking a repeating task makes the next"
    tick reopen "$id" "Water the plants"
    [ "$(water)" = '[["2026-11-20",false],["2026-11-27",false]]' ] || fail "unticking a repeating task only reopens it, the next one todoman made kept"

    # A long line folds onto the next after a space (RFC 5545): reopen drops a folded completion whole, the folded note beside it as it was.
    ! tick reopen "$(todo list --status ANY | jq '.[] | select(.summary == "Done long ago") | .id')" "Done long ago" 2> err && grep -q "tasks changed, try again" err \
      || fail "a tick of a task the file leaves out fails, as its id may since name another alike"
    sed "s/^COMPLETED:20260102/COMPLETED:$(date -u +%Y%m%d)/" ${./personal/old.ics} > state/vdirs/personal/old.ics
    sync tasks
    tick reopen "$(jq -r '.tasks[] | select(.title == "Done long ago") | .id' state/tasks.json)" "Done long ago"
    diff <(others ${./personal/old.ics}) <(others state/vdirs/personal/old.ics) || fail "reopen reads folded lines whole"
    grep -qx $'STATUS:NEEDS-ACTION\r' state/vdirs/personal/old.ics || fail "reopen marks the file as needing action, in its line endings"

    # A tick leaves every line it does not set: a parameter, a property on two lines and a time's zone are kept.
    install -m 644 ${./added}/errands.ics state/vdirs/personal/errands.ics
    sync tasks
    tick done "$(jq -r '.tasks[] | select(.title == "Run errands") | .id' state/tasks.json)" "Run errands"
    diff <(others ${./added}/errands.ics) <(others state/vdirs/personal/errands.ics) && completed state/vdirs/personal/errands.ics \
      || fail "done keeps every line it does not set, a language, categories on two lines and a time's zone included"
    ! grep -q $'\r' state/vdirs/personal/errands.ics || fail "done keeps a file's bare newlines"

    # Two tasks alike: an id renumbered onto the other still has its title, so a tick of either is refused rather than guessed.
    for f in milk-home milk-office; do install -m 644 ${./added}/$f.ics state/vdirs/personal/$f.ics; done
    sync tasks
    ! tick done "$(jq -r 'first(.tasks[] | select(.title == "Buy milk")) | .id' state/tasks.json)" "Buy milk" 2> err || fail "a done of one of two open tasks alike fails"
    grep -q "two tasks are called Buy milk" err && cmp ${./added}/milk-home.ics state/vdirs/personal/milk-home.ics && cmp ${./added}/milk-office.ics state/vdirs/personal/milk-office.ics \
      || fail "a done of one of two open tasks alike says so, touching neither"

    # A series with an instance of its own in one file, done this week: todoman lists it once, and an edit would reach all.
    sed "s/^COMPLETED:2026[0-9]*T/COMPLETED:$(date -u +%Y%m%d)T/" ${./added}/review.ics > review.ics && cp review.ics state/vdirs/personal/review.ics
    sync tasks
    ! tick reopen "$(jq -r '.tasks[] | select(.title == "Weekly review") | .id' state/tasks.json)" "Weekly review" 2> err || fail "a tick of a file of more than one task fails"
    grep -q "holds more than one task" err && cmp review.ics state/vdirs/personal/review.ics || fail "a tick of a file of more than one task says so, touching it not"

    quick-key-calendar-sync add ${./calendars.yaml} state/events.json "-Call the plumber"
    [ "$(jq -c '.tasks[] | select(.title == "-Call the plumber") | [.done, .due]' state/tasks.json)" = '[false,null]' ] || fail "add writes an open, undated task, a title like an option included"
    for title in -x --help; do
      quick-key-calendar-sync add ${./calendars.yaml} state/events.json -- "$title"
      jq -e --arg t "$title" '[.tasks[] | select(.title == $t)] | length == 1' state/tasks.json > /dev/null || fail "add takes a title like a flag after --, as the module passes it: $title"
    done
    grep -lq '^SUMMARY:-Call the plumber' state/vdirs/personal/*.ics || fail "add writes it to the first list"
    [ ! -e state/__pycache__ ] || fail "todoman leaves no bytecode beside its config"

    # The file says when the lists last synced, and how the last sync went, whatever wrote it since.
    jq -c '.updated = "2026-01-01T00:00" | .error = "personal: could not sync"' state/tasks.json > state/old.json && mv state/old.json state/tasks.json
    tick done "$(task | jq -r .id)" "Pay the bills"
    jq -e '.updated == "2026-01-01T00:00" and .error == "personal: could not sync"' state/tasks.json > /dev/null || fail "a tick keeps when it last synced, and its error"
    sync tasks --error "personal: offline"
    jq -e '.updated == "2026-01-01T00:00" and .error == "personal: offline"' state/tasks.json > /dev/null || fail "a sync that fetched no list keeps when it last synced"
    sync tasks --synced
    jq -e --arg today "$(date +%Y-%m-%d)" '(.updated | startswith($today)) and (has("error") | not)' state/tasks.json > /dev/null || fail "a sync that fetched the lists says when, and clears the error"

    # Events, from a calendar served as an http one is, dated from today so it falls in the weeks the month reads.
    events() { jq -c '.events[] | [.title, .start, .allDay, .color, .location]' events/events.json; }
    efail() { echo "not ok - $1"; cat events/events.json; exit 1; }
    mkdir served
    day=$(date -d tomorrow +%Y%m%d)
    printf 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:lunch@test\r\nDTSTAMP:20260101T000000Z\r\nDTSTART:%sT130000\r\nDTEND:%sT140000\r\nSUMMARY:Lunch\r\nLOCATION:Rua Augusta 120\r\nEND:VEVENT\r\nBEGIN:VEVENT\r\nUID:standup@test\r\nDTSTAMP:20260101T000000Z\r\nDTSTART:%sT090000\r\nDTEND:%sT091500\r\nSUMMARY:Standup\r\nSTATUS:CANCELLED\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' "$day" "$day" "$day" "$day" > served/work.ics
    # Served as http.server does, but a request while `arm` exists leaves the word a tick would, as if one came mid-sync.
    python3 -c '
    import functools, http.server, os
    class Handler(http.server.SimpleHTTPRequestHandler):
        def do_GET(self):
            if os.path.exists("arm"):
                os.remove("arm")
                open("events/changed", "w").close()
            super().do_GET()
    http.server.ThreadingHTTPServer(("127.0.0.1", 8765), functools.partial(Handler, directory="served")).serve_forever()
    ' > server.log 2>&1 &
    for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/8765) 2>/dev/null && break; sleep 0.1; done
    printf -- '- name: work\n  url: http://127.0.0.1:8765/work.ics\n  color: "#3366ff"\n' > work.yaml
    quick-key-calendar-sync work.yaml events/events.json || efail "a sync from a calendar it reaches succeeds"
    [ "$(events)" = "[\"Lunch\",\"$(date -d tomorrow +%F)T13:00\",false,\"#3366ff\",\"Rua Augusta 120\"]" ] || efail "an event reads with its local time, its calendar's colour and where, a cancelled one left out"
    jq -e '.events[0].uid | length > 0' events/events.json > /dev/null || efail "an event has a uid, which tells apart two alike"
    jq -e '.updated and (has("error") | not) and (has("syncing") | not)' events/events.json > /dev/null || efail "a sync done says when, and no longer that it syncs"
    jq -e --arg from "$(date -d '62 days ago' +%F)" --arg to "$(date -d '365 days' +%F)" '.synced == { from: $from, to: $to }' events/events.json > /dev/null || efail "a sync says the days it covers"

    gets() { grep -c 'GET /work.ics' server.log; }
    before=$(gets); quick-key-calendar-sync work.yaml events/events.json; once=$(( $(gets) - before ))
    touch arm; before=$(gets); quick-key-calendar-sync work.yaml events/events.json; twice=$(( $(gets) - before ))
    [ "$once" -gt 0 ] && [ "$twice" = $((2 * once)) ] && [ ! -e events/changed ] || efail "a tick during a sync makes it sync again, once ($once, then $twice)"

    printf -- '- name: work\n  url: http://127.0.0.1:1/secret-token/work.ics\n  color: "#3366ff"\n' > gone.yaml
    ! quick-key-calendar-sync gone.yaml events/events.json || efail "a sync whose server is gone fails"
    [ "$(events | wc -l)" = 1 ] || efail "a failed sync keeps the last events"
    jq -e '.error | startswith("work: ")' events/events.json > /dev/null || efail "a failed sync names the calendar"
    ! grep -q secret-token events/events.json || efail "a failed sync's reason leaves the address out"
    ! grep -q '127\.0\.0\.1' events/events.json || efail "a failed sync's reason leaves the host out, bare as a library names it"
    touch $out
  ''
