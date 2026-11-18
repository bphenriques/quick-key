# Takes the docs' images of the deployed menu on the live niri desktop, with made-up events and a canned assistant. Usage: shots.sh <images dir>
set -euo pipefail

out=$(realpath "${1:?usage: shots.sh <images dir>}")
events=$(dirname "$(realpath "$0")")/../../record-tour/scripts/events.json
work=$(mktemp -d)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
NIRI_SOCKET=${NIRI_SOCKET:-$(ls "$XDG_RUNTIME_DIR"/niri.*.sock | head -1)}
export NIRI_SOCKET
cfg=${XDG_CONFIG_HOME:-$HOME/.config}/quick-key/config.json

jq '
  def date(d): now + d * 86400 | localtime | strftime("%Y-%m-%d");
  { updated: (now | localtime | strftime("%Y-%m-%dT%H:%M")),
    events: map(
      { title, color, location }
      + if .start then { allDay: false, start: "\(date(.day))T\(.start)", end: "\(date(.day))T\(.end)" }
        else { allDay: true, start: date(.day), end: date(.day + (.days // 1) - 1) } end
      | with_entries(select(.value != null))) }
' "$events" > "$work/events.json"

# The live config with those events, minus Wi-Fi, whose status names the network, and an assistant that always answers the same.
reply='{"reply":"Tomorrow: team standup at 09:30, then lunch with Ana at 13:00 (Time Out Market).\nFriday is free after 15:00, a good slot for the dentist."}'
jq --arg file "$work/events.json" --arg r "$reply" --arg p "printf '%s\\n' " '
  .calendar.file = $file | del(.calendar.remind) | .menu.entries |= map(select(.list != "wifi"))
  | .plugins.ask.ask = ($p + ($r | @sh) + "; :") | .plugins.ask.title = "Assistant"
' "$cfg" > "$work/config.json"

output=$(niri msg --json focused-output)
read -r ox oy ow oh < <(jq -r '.logical | "\(.x) \(.y) \(.width) \(.height)"' <<<"$output")
name=$(jq -r .name <<<"$output")
back=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .idx')
empty=$(niri msg --json workspaces | jq --arg o "$name" '[.[] | select(.output == $o and .active_window_id == null)] | max_by(.idx) | .idx')

restore() {
  mv -f "$work/config.orig" "$cfg"
  systemctl --user restart quick-key.service
  niri msg action focus-workspace "$back"
  rm -rf "$work"
}
mv "$cfg" "$work/config.orig"
trap restore EXIT
cp "$work/config.json" "$cfg"
niri msg action focus-workspace "$empty"
systemctl --user restart quick-key.service
sleep 4

# Each panel sits bottom centre, theme.edgeMargin (35) over the bottom: a frame of its size with a margin around it, 15 short of the bottom.
shot() {
  local file=$1 width=$2 height=$3
  sleep 1.5
  grim -g "$((ox + (ow - width) / 2)),$((oy + oh - 15 - height)) ${width}x${height}" "$out/$file.png"
}
ipc() { qs -c quick-key ipc call "$@"; }

ipc menu toggle; shot menu 1008 257; ipc menu toggle; sleep 0.5
ipc menu toggleEntry a; shot speakers 688 309; ipc menu toggleEntry a; sleep 0.5
ipc menu toggleEntry c; shot calendar 1008 417; ipc menu toggleEntry c; sleep 0.5
ipc ask activate; sleep 1
wtype -k Shift_L
wtype "What's on this week?"; wtype -k Return
shot ask 1008 488
ipc ask activate
ls "$out"
