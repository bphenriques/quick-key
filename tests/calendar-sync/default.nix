# calendar-sync offline: the tasks file from a synced folder written as the iPhone writes, then a tick, an untick and an added task there; then a whole sync of events from a calendar served on loopback, and one whose server is gone.
{ pkgs, self }:
pkgs.runCommand "quick-key-calendar-sync"
  {
    nativeBuildInputs = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key-calendar-sync
      pkgs.jq
      pkgs.python3
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
    task() { jq -c '.tasks[] | select(.title == "Pay the bills")' state/tasks.json; }
    fail() { echo "not ok - $1"; cat state/tasks.json; exit 1; }

    sync tasks
    jq -e 'has("updated") | not' state/tasks.json > /dev/null || fail "a tasks file never synced says no sync"
    [ "$(jq '.tasks | length' state/tasks.json)" = 1 ] || fail "a task done more than 14 days ago is left out"
    [ "$(task | jq -c '[.due, .done, .list, .priority, .color]')" = '["2026-10-06T09:00",false,"personal",1,"#ff8c00"]' ] || fail "a task reads with its local time, open, with its list, priority and calendar's colour"

    id=$(task | jq -r .id)
    quick-key-calendar-sync done ${./calendars.yaml} state/events.json "$id"
    [ "$(task | jq .done)" = true ] || fail "done ticks it off in the tasks file"
    task | jq -r .completed | grep -q "^$(date +%Y-%m-%d)" || fail "done says when, so the done ones can be shown"
    grep -q '^STATUS:COMPLETED' state/vdirs/personal/bills.ics || fail "done marks the file completed"
    grep -q '^BEGIN:VALARM' state/vdirs/personal/bills.ics || fail "done keeps the reminder"

    id=$(task | jq -r .id)
    quick-key-calendar-sync reopen ${./calendars.yaml} state/events.json "$id"
    [ "$(task | jq .done)" = false ] || fail "reopen unticks it in the tasks file"
    grep -q '^STATUS:NEEDS-ACTION' state/vdirs/personal/bills.ics || fail "reopen marks the file as needing action"
    ! grep -qE '^(COMPLETED|PERCENT-COMPLETE)' state/vdirs/personal/bills.ics || fail "reopen drops the record of completion"
    grep -q '^BEGIN:VALARM' state/vdirs/personal/bills.ics || fail "reopen keeps the reminder"

    quick-key-calendar-sync add ${./calendars.yaml} state/events.json "-Call the plumber"
    [ "$(jq -c '.tasks[] | select(.title == "-Call the plumber") | [.done, .due]' state/tasks.json)" = '[false,null]' ] || fail "add writes an open, undated task, a title like an option included"
    grep -lq '^SUMMARY:-Call the plumber' state/vdirs/personal/*.ics || fail "add writes it to the first list"
    [ ! -e state/__pycache__ ] || fail "todoman leaves no bytecode beside its config"

    # The file says when the lists last synced, and how the last sync went, whatever wrote it since.
    jq -c '.updated = "2026-01-01T00:00" | .error = "personal: could not sync"' state/tasks.json > state/old.json && mv state/old.json state/tasks.json
    quick-key-calendar-sync done ${./calendars.yaml} state/events.json "$(task | jq -r .id)"
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
    printf 'BEGIN:VCALENDAR\r\nVERSION:2.0\r\nPRODID:-//test//EN\r\nBEGIN:VEVENT\r\nUID:lunch@test\r\nDTSTAMP:20260101T000000Z\r\nDTSTART:%sT130000\r\nDTEND:%sT140000\r\nSUMMARY:Lunch\r\nLOCATION:Rua Augusta 120\r\nEND:VEVENT\r\nEND:VCALENDAR\r\n' "$day" "$day" > served/work.ics
    python3 -m http.server 8765 --bind 127.0.0.1 --directory served > server.log 2>&1 &
    for _ in $(seq 50); do (exec 3<>/dev/tcp/127.0.0.1/8765) 2>/dev/null && break; sleep 0.1; done
    printf -- '- name: work\n  url: http://127.0.0.1:8765/work.ics\n  color: "#3366ff"\n' > work.yaml
    quick-key-calendar-sync work.yaml events/events.json || efail "a sync from a calendar it reaches succeeds"
    [ "$(events)" = "[\"Lunch\",\"$(date -d tomorrow +%F)T13:00\",false,\"#3366ff\",\"Rua Augusta 120\"]" ] || efail "an event reads with its local time, its calendar's colour and where"
    jq -e '.updated and (has("error") | not) and (has("syncing") | not)' events/events.json > /dev/null || efail "a sync done says when, and no longer that it syncs"

    printf -- '- name: work\n  url: http://127.0.0.1:1/secret-token/work.ics\n  color: "#3366ff"\n' > gone.yaml
    ! quick-key-calendar-sync gone.yaml events/events.json || efail "a sync whose server is gone fails"
    [ "$(events | wc -l)" = 1 ] || efail "a failed sync keeps the last events"
    jq -e '.error | startswith("work: ")' events/events.json > /dev/null || efail "a failed sync names the calendar"
    ! grep -q secret-token events/events.json || efail "a failed sync's reason leaves the address out"
    touch $out
  ''
