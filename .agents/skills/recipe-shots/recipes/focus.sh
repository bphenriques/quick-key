ipc menu toggle
key -M ctrl f -m ctrl
shot focus 1.5
ipc menu toggle
# The timer runs for real: stop it and clear its state, which lives in the real $XDG_RUNTIME_DIR.
pkill -f '^sh -c for m in \$\(seq 25' || true
rm -f "$XDG_RUNTIME_DIR/focus"
