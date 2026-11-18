# The tasks plugin's commands over a tasks file: `write` makes one around today (updated at $2, else now), `many` one of ten late tasks, `broken` one whose sync failed, `done` and `reopen` flip a task after a moment (task d fails), `sync` and `remind` leave a trace.
file="$XDG_RUNTIME_DIR/tasks"
case "$1" in
  write)
    printf '{"updated":"%s","tasks":[%s,%s,%s,%s,%s,%s]}\n' "${2:-$(date +%Y-%m-%dT%H:%M)}" \
      '{"id":"d","done":false,"title":"Undated"}' \
      "{\"id\":\"c\",\"done\":false,\"title\":\"Later\",\"due\":\"$(date -d tomorrow +%Y-%m-%d)\"}" \
      "{\"id\":\"b\",\"done\":false,\"title\":\"Now\",\"due\":\"$(date +%Y-%m-%dT%H:%M)\"}" \
      "{\"id\":\"a\",\"done\":false,\"title\":\"Late\",\"due\":\"$(date -d yesterday +%Y-%m-%d)\"}" \
      "{\"id\":\"e\",\"done\":true,\"title\":\"Ticked\",\"due\":\"$(date -d yesterday +%Y-%m-%d)\"}" \
      "{\"id\":\"f\",\"done\":false,\"title\":\"Today\",\"due\":\"$(date +%Y-%m-%d)\"}" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  many)
    tasks=$(seq 10 | sed "s/.*/{\"id\":\"&\",\"done\":false,\"title\":\"Late &\",\"due\":\"$(date -d yesterday +%Y-%m-%d)\"}/" | paste -sd,)
    echo "{\"updated\":\"$(date +%Y-%m-%dT%H:%M)\",\"tasks\":[$tasks]}" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  done | reopen)
    sleep 0.5
    [ "$2" = d ] && exit 1
    [ "$1" = done ] && from=false to=true || from=true to=false
    sed "s/\"id\":\"$2\",\"done\":$from/\"id\":\"$2\",\"done\":$to/" "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  broken)
    echo "{\"updated\":\"$(date +%Y-%m-%dT%H:%M)\",\"error\":\"personal: could not sync\",\"tasks\":[]}" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  broken)
    echo "{\"updated\":\"$(date +%Y-%m-%dT%H:%M)\",\"error\":\"personal: could not sync\",\"tasks\":[]}" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  sync) echo synced > "$XDG_RUNTIME_DIR/synced" ;;
  unsync) rm -f "$XDG_RUNTIME_DIR/synced" ;;
  remind) echo "$2 $3" > "$XDG_RUNTIME_DIR/reminded" ;;
esac
