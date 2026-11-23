# Runs a working tree of the shell in a nested niri, then opens a shell inside it to drive it, or runs a steps file and exits.
dir=$(realpath "${1:?usage: quick-key-preview <shell dir> [config.json] [steps.sh]}")
config_home=${XDG_CONFIG_HOME:-$HOME/.config}
config=$(realpath "${2:-$config_home/quick-key/config.json}")
: "${WAYLAND_DISPLAY:?run inside a Wayland session}"

work=$(mktemp -d)
trap 'kill $(jobs -p) 2>/dev/null; rm -rf "$work"' EXIT

# Your config, for fonts and icons, and the shell's folder (themes, plugins) with this config.json in place of its own.
mkdir "$work/config" "$work/config.shell"
ln -s "$config_home"/* "$work/config/"
rm -f "$work/config/quick-key"
for entry in "$config_home"/quick-key/*; do
  if [ -e "$entry" ] && [ "$(basename "$entry")" != config.json ]; then ln -s "$entry" "$work/config.shell/"; fi
done
mv "$work/config.shell" "$work/config/quick-key"
cp "$config" "$work/config/quick-key/config.json"

# A copy of your state (tasks, events), so plugins read it as they would, but what they write, a sync's result, stays in the preview.
state_home=${XDG_STATE_HOME:-$HOME/.local/state}
mkdir "$work/state"
if [ -d "$state_home/quick-key" ]; then cp -r "$state_home/quick-key" "$work/state/"; fi
# A path to it the config spells out (as the module writes them) points at the copy too.
sed -i "s|$state_home/quick-key|$work/state/quick-key|g" "$work/config/quick-key/config.json"

# niri runs the command once it is up, which reports where; the read waits for it, opened read-write so the open itself cannot block.
mkfifo "$work/ready"
exec 3<>"$work/ready"
# shellcheck disable=SC2016 # expanded by niri's child, inside the nested session
niri -c "$PREVIEW_NIRI_CONFIG" -- sh -c 'printf "%s %s\n" "$WAYLAND_DISPLAY" "$NIRI_SOCKET" > "$1"' sh "$work/ready" > "$work/niri.log" 2>&1 &
if ! read -r -t 30 -u 3 display socket; then
  echo "nested niri did not start; its log:" >&2
  cat "$work/niri.log" >&2
  exit 1
fi
export WAYLAND_DISPLAY=$display NIRI_SOCKET=$socket

XDG_CONFIG_HOME=$work/config XDG_STATE_HOME=$work/state quickshell -p "$dir" > "$work/quickshell.log" 2>&1 &
shell_pid=$!

# shellcheck disable=SC2329 # a steps file calls these, then the preview ends; shots land in the working directory
if [ -n "${3:-}" ]; then
  ipc() { quickshell ipc --pid "$shell_pid" call "$@"; }
  key() { wtype "$@"; sleep 0.3; }
  shot() { sleep "${2:-0.8}"; grim "$1.png"; }
  sleep 5
  kill -0 "$shell_pid" 2>/dev/null || { cat "$work/quickshell.log" >&2; exit 1; }
  # wtype drops the first key it sends.
  wtype -k Shift_L
  # shellcheck source=/dev/null
  . "$(realpath "$3")"
  grep -E "WARN (scene|qml)|TypeError" "$work/quickshell.log" >&2 || true
  exit
fi


cat <<HELP
Shell running in the nested niri; its log: $work/quickshell.log. Exit this shell to stop both.
  quickshell -p $dir ipc call menu toggle
  wtype a                                 # a key; wtype -P Super_L -s 1500 -p Super_L holds one
  wlrctl pointer move -5000 -5000         # to the top left, then relative moves; wlrctl pointer click left
  grim shot.png
Session actions run for real.
HELP
"${SHELL:-bash}"
