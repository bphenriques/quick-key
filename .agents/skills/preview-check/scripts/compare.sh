# Runs one steps file in the preview against two trees and compares each shot. Usage: compare.sh <base ref> <config.json> <steps.sh> [out dir]
set -euo pipefail
root=$(realpath "$(dirname "$(realpath "$0")")/../../../..")
base=$1 config=$(realpath "$2") steps=$(realpath "$3")
out=$(realpath -m "${4:-$(mktemp -d)}")
preview=$(nix build --no-link --print-out-paths "$root#quick-key-preview")/bin/quick-key-preview
PATH=$(nix build --no-link --print-out-paths nixpkgs#imagemagick | sed 's|$|/bin|'):$PATH
export WAYLAND_DISPLAY=${WAYLAND_DISPLAY:-wayland-1}

tree=$(mktemp -d)
trap 'git -C "$root" worktree remove --force "$tree" >/dev/null 2>&1 || true' EXIT
git -C "$root" worktree add --detach -q "$tree" "$base"

run() {
  mkdir -p "$out/$1"
  # The preview prints the shell's warnings on stderr, colour codes stripped; the portal's and the bus's noise is dropped.
  (cd "$out/$1" && timeout 300 dbus-run-session -- "$preview" "$2/packages/quick-key" "$config" "$steps") 2>&1 \
    | grep -vE 'xdg-desktop-portal|dbus-daemon|fusermount|bus can.t be made|^$' | sed "s/^/$1: /" || true
}
run base "$tree"
run new "$root"

status=0
for shot in "$out"/base/*.png; do
  name=$(basename "$shot")
  [ -e "$out/new/$name" ] || { echo "$name: missing in new"; status=1; continue; }
  differ=$(magick compare -metric AE -fuzz 2% "$shot" "$out/new/$name" "$out/diff-$name" 2>&1 >/dev/null | cut -d' ' -f1 || true)
  echo "$name: $differ pixels differ"
  [ "$differ" = 0 ] || status=1
done
echo "shots in $out"
exit $status
