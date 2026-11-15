# An agent that works until it is ended, and says so where the `trapped` plugin reads it.
trap 'kill $!; echo stopped > "$XDG_RUNTIME_DIR/trapped"; exit' TERM
echo '{"status": "thinking"}'
sleep 30 &
wait
