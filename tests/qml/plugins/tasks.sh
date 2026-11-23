# The tasks plugin's commands over a tasks file: `write` makes one around today (updated at $2, else now), `many` one of ten late tasks, `missed` one whose reminder fell due five minutes ago, `broken` one whose sync failed, `done` and `reopen` flip a task after a moment (task d fails, and once `stick` has run the next leaves the file as it was), `add` adds one (Fail fails), `sync` and `remind` leave a trace.
file="$XDG_RUNTIME_DIR/tasks"
case "$1" in
  write)
    printf '{"updated":"%s","tasks":[%s,%s,%s,%s,%s,%s]}\n' "${2:-$(date +%Y-%m-%dT%H:%M)}" \
      '{"id":"d","done":false,"title":"Undated","list":"home"}' \
      "{\"id\":\"c\",\"done\":false,\"title\":\"Later\",\"list\":\"work\",\"due\":\"$(date -d tomorrow +%Y-%m-%d)\"}" \
      "{\"id\":\"b\",\"done\":false,\"title\":\"Now\",\"list\":\"home\",\"priority\":1,\"due\":\"$(date +%Y-%m-%dT%H:%M)\"}" \
      "{\"id\":\"a\",\"done\":false,\"title\":\"Late\",\"list\":\"work\",\"priority\":5,\"color\":\"#4285f4\",\"due\":\"$(date -d yesterday +%Y-%m-%d)\"}" \
      "{\"id\":\"e\",\"done\":true,\"title\":\"Ticked\",\"list\":\"home\",\"due\":\"$(date -d yesterday +%Y-%m-%d)\",\"completed\":\"$(date +%Y-%m-%d)T09:00\"}" \
      "{\"id\":\"f\",\"done\":false,\"title\":\"Today\",\"list\":\"home\",\"due\":\"$(date +%Y-%m-%d)\"}" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  many)
    tasks=$(seq 10 | sed "s/.*/{\"id\":\"&\",\"done\":false,\"title\":\"Late &\",\"due\":\"$(date -d yesterday +%Y-%m-%d)\"}/" | paste -sd,)
    echo "{\"updated\":\"$(date +%Y-%m-%dT%H:%M)\",\"tasks\":[$tasks]}" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  add)
    sleep 0.5
    [ "$2" = Fail ] && exit 1
    sed "s/\"tasks\":\[/\"tasks\":[{\"id\":\"n\",\"done\":false,\"title\":\"$2\"},/" "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  stick) touch "$XDG_RUNTIME_DIR/stuck" ;;
  done | reopen)
    sleep 0.5
    [ "$2" = d ] && exit 1
    rm "$XDG_RUNTIME_DIR/stuck" 2>/dev/null && exit 0
    [ "$1" = done ] && from=false to=true || from=true to=false
    sed "s/\"id\":\"$2\",\"done\":$from/\"id\":\"$2\",\"done\":$to/" "$file" > "$file.tmp"
    mv "$file.tmp" "$file"
    ;;
  missed)
    echo "{\"updated\":\"$(date +%Y-%m-%dT%H:%M)\",\"tasks\":[{\"id\":\"m\",\"done\":false,\"title\":\"Missed\",\"due\":\"$(date -d '5 minutes ago' +%Y-%m-%dT%H:%M)\"}]}" > "$file.tmp"
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
