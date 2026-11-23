# Takes each recipe's images in the preview: base.jq over the starter menu, then recipes/<name>.jq, driven by recipes/<name>.sh, each shot cropped to what it shows. Usage: shot.sh <name>...
set -euo pipefail
here=$(dirname "$(realpath "$0")")
recipes=$here/../recipes
root=$(realpath "$here/../../../..")
images=$root/docs/src/images
preview=$(nix build --no-link --print-out-paths "$root#quick-key-preview")/bin/quick-key-preview
PATH=$(nix build --no-link --print-out-paths nixpkgs#imagemagick nixpkgs#jq | sed 's|$|/bin|' | paste -sd:):$PATH
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}

for name in "$@"; do
  work=$(mktemp -d)
  jq --arg events "$root/packages/preview/events.json" -f "$here/base.jq" "$root/packages/quick-key/menu.json" \
    | jq -f "$recipes/$name.jq" > "$work/config.json"
  echo "$name:"
  # The session bus is the preview's own, so no tray app or player of yours shows; the portal's noise is dropped.
  (cd "$work" && timeout 120 dbus-run-session -- "$preview" "$root/packages/quick-key" config.json "$(realpath "$recipes/$name.sh")") 2>&1 \
    | sed 's/\x1b\[[0-9;]*m//g' | grep -vE 'xdg-desktop-portal|dbus-daemon|fusermount|bus can.t be made|^$' || true
  for png in "$work"/*.png; do
    [ -e "$png" ] || { echo "  no shot taken" >&2; exit 1; }
    # Cropped to what differs from the empty output, with a margin of it.
    background=$(magick "$png" -format '%[pixel:p{0,0}]' info:)
    magick "$png" -fuzz 2% -trim +repage -bordercolor "$background" -border 16 -strip "$images/$(basename "$png")"
    echo "  $images/$(basename "$png") $(magick identify -format '%wx%h' "$images/$(basename "$png")")"
  done
  rm -rf "$work"
done
