# Records a short tour of the deployed menu on the live niri desktop, with made-up events. Usage: record.sh <out.mp4>
set -euo pipefail

out=$(realpath -m "${1:?usage: record.sh <out.mp4>}")
here=$(dirname "$(realpath "$0")")
work=$(mktemp -d)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
NIRI_SOCKET=${NIRI_SOCKET:-$(ls "$XDG_RUNTIME_DIR"/niri.*.sock | head -1)}
export NIRI_SOCKET
cfg=${XDG_CONFIG_HOME:-$HOME/.config}/quick-key/config.json

# Events dated from today, so the month always has something to show.
jq '
  def date(d): now + d * 86400 | localtime | strftime("%Y-%m-%d");
  { updated: (now | localtime | strftime("%Y-%m-%dT%H:%M")),
    events: map(
      { title, color, location }
      + if .start then { allDay: false, start: "\(date(.day))T\(.start)", end: "\(date(.day))T\(.end)" }
        else { allDay: true, start: date(.day), end: date(.day + (.days // 1) - 1) } end
      | with_entries(select(.value != null))) }
' "$here/events.json" > "$work/events.json"

# The live config with those events, minus Wi-Fi, whose status names the network.
jq --arg file "$work/events.json" '
  .calendar.file = $file | del(.calendar.remind) | .menu.entries |= map(select(.list != "wifi"))
' "$cfg" > "$work/config.json"

output=$(niri msg --json focused-output)
read -r ox oy ow oh < <(jq -r '.logical | "\(.x) \(.y) \(.width) \(.height)"' <<<"$output")
name=$(jq -r .name <<<"$output")
back=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .idx')
empty=$(niri msg --json workspaces | jq --arg o "$name" '[.[] | select(.output == $o and .active_window_id == null)] | max_by(.idx) | .idx')

restore() {
  mv -f "$work/config.orig" "$cfg"
  systemctl --user restart quickshell.service
  niri msg action focus-workspace "$back"
  rm -rf "$work"
}
mv "$cfg" "$work/config.orig"
trap restore EXIT
cp "$work/config.json" "$cfg"
niri msg action focus-workspace "$empty"
systemctl --user restart quickshell.service
sleep 4

# The menu sits bottom centre; this frame fits its largest level at the default size.
w=1040 h=460
wl-screenrec -g "$((ox + (ow - w) / 2)),$((oy + oh - h)) ${w}x${h}" -f "$work/raw.mp4" >/dev/null 2>&1 &
recorder=$!
sleep 1

key() { wtype -k "$1"; sleep "$2"; }
qs -c quick-key ipc call menu toggle; sleep 2.5
wtype a; sleep 2.5
key BackSpace 1
wtype c; sleep 2
key Right 0.7
key Right 0.7
key Down 1
key Return 1.2
key Down 1
key Down 1.5
key BackSpace 0.8
key BackSpace 1.2
key Escape 1

kill -INT "$recorder"
wait "$recorder" || true
ffmpeg -v error -y -i "$work/raw.mp4" -vf fps=30,format=yuv420p -c:v libx264 -preset slow -crf 22 -movflags +faststart -an "$out"
echo "$out"
