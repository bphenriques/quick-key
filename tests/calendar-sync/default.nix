# calendar-sync's tasks, offline: the tasks file from a synced folder written as the iPhone writes, then a tick, an untick and an added task there.
{ pkgs, self }:
pkgs.runCommand "quick-key-calendar-sync"
  {
    nativeBuildInputs = [
      self.packages.${pkgs.stdenv.hostPlatform.system}.quick-key-calendar-sync
      pkgs.jq
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
    [ "$(jq '.tasks | length' state/tasks.json)" = 1 ] || fail "a task done before today is left out"
    [ "$(task | jq -c '[.due, .done, .color]')" = '["2026-10-06T09:00",false,"#ff8c00"]' ] || fail "a task reads with its local time, open, in its calendar's colour"

    id=$(task | jq -r .id)
    quick-key-calendar-sync done ${./calendars.yaml} state/events.json "$id"
    [ "$(task | jq .done)" = true ] || fail "done ticks it off in the tasks file"
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
    touch $out
  ''
