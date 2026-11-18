# An agent that names a session of its own and replies with the prompt it was given.
echo '{"session": "s2"}'
printf '{"reply": "%s"}\n' "$1"
