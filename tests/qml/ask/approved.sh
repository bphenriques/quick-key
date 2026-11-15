# An agent that names its session, asks for an approval and replies with the answer.
echo '{"session": "s1"}'
echo '{"approval": "rm"}'
read -r answer
echo "{\"reply\": \"$answer\"}"
