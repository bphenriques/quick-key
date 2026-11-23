# Takes the docs' images of a shell on the live niri desktop, as a second instance with made-up events and a canned agent. Usage: shots.sh <images dir> [shell dir]
set -euo pipefail
pgrep -x hyprlock >/dev/null && { echo "Session locked: unlock first." >&2; exit 1; }

out=$(realpath "${1:?usage: shots.sh <images dir> [shell dir]}")
here=$(dirname "$(realpath "$0")")
shell=$(realpath "${2:-$here/../../../../packages/quick-key}")
work=$(mktemp -d)
export XDG_RUNTIME_DIR=${XDG_RUNTIME_DIR:-/run/user/$(id -u)}
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}
NIRI_SOCKET=${NIRI_SOCKET:-$(ls "$XDG_RUNTIME_DIR"/niri.*.sock | head -1)}
export NIRI_SOCKET
python=$(nix build --no-link --print-out-paths --impure --expr '(builtins.getFlake "nixpkgs").legacyPackages.${builtins.currentSystem}.python3.withPackages (ps: [ ps.agent-client-protocol ])')/bin/python3

jq '
  def date(d): now + d * 86400 | localtime | strftime("%Y-%m-%d");
  { updated: (now | localtime | strftime("%Y-%m-%dT%H:%M")),
    events: map(
      { title, color, location }
      + if .start then { allDay: false, start: "\(date(.day))T\(.start)", end: "\(date(.day))T\(.end)" }
        else { allDay: true, start: date(.day), end: date(.day + (.days // 1) - 1) } end
      | with_entries(select(.value != null))) }
' "$here/../../record-tour/scripts/events.json" > "$work/events.json"

# The live config with those events, minus Wi-Fi, whose status names the network, the canned agent under a generic name, and the sizes the frames below expect.
mkdir -p "$work/config/quick-key"
ln -s "${XDG_CONFIG_HOME:-$HOME/.config}/fontconfig" "$work/config/fontconfig"
jq --arg file "$work/events.json" --arg agent "$python $here/agent.py" '
  .menu.width = 960 | .theme.edgeMargin = 35
  | .calendar.file = $file | del(.calendar.remind) | .menu.entries |= map(select(.list != "wifi"))
  | .plugins.ask = { ask: $agent, title: "Assistant" } | if .menu.input then .menu.input.desc = "Ask Assistant" else . end
' "${XDG_CONFIG_HOME:-$HOME/.config}/quick-key/config.json" > "$work/config/quick-key/config.json"

output=$(niri msg --json focused-output)
read -r ox oy ow oh < <(jq -r '.logical | "\(.x) \(.y) \(.width) \(.height)"' <<<"$output")
name=$(jq -r .name <<<"$output")
back=$(niri msg --json workspaces | jq '.[] | select(.is_focused) | .idx')
empty=$(niri msg --json workspaces | jq --arg o "$name" '[.[] | select(.output == $o and .active_window_id == null)] | max_by(.idx) | .idx')

# A copy, whose path keys a saved state of its own, so no earlier run's conversation shows.
cp -r --no-preserve=mode "$shell" "$work/shell"
XDG_CONFIG_HOME=$work/config quickshell -p "$work/shell" > "$work/qs.log" 2>&1 &
pid=$!
trap 'quickshell kill --pid $pid >/dev/null 2>&1 || kill $pid; niri msg action focus-workspace "$back"; rm -rf "$work"' EXIT
niri msg action focus-workspace "$empty"
# The pointer in a corner, so no row shows hovered.
wlrctl pointer move -100000 -100000
sleep 4

# Each panel sits bottom centre, theme.edgeMargin (35) over the bottom: a frame of its size with a margin around it, 15 short of the bottom.
shot() {
  local file=$1 width=$2 height=$3
  sleep 1.5
  grim -s 1 -g "$((ox + (ow - width) / 2)),$((oy + oh - 15 - height)) ${width}x${height}" "$out/$file.png"
}
ipc() { quickshell ipc --pid "$pid" call "$@"; }

ipc menu toggle; shot menu 1008 290; ipc menu toggle; sleep 0.5
ipc menu toggleEntry a; shot speakers 768 309; ipc menu toggleEntry a; sleep 0.5
ipc menu toggleEntry c; shot calendar 1008 450; ipc menu toggleEntry c; sleep 0.5
ipc ask activate; sleep 1
wtype -k Shift_L
wtype "What's on this week?"; wtype -k Return
shot ask 1008 488
ipc ask activate
ls "$out"
