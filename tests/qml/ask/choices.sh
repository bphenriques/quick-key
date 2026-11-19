# An agent whose answers carry structure: a table when asked for one, else options, then whatever it was sent.
echo '{"session": "s3"}'
case "$1" in
  *table*) printf '{"reply": "seg 10:00  Café\\nqua 18:00  Ginásio", "table": true}\n' ;;
  pick*) printf '{"reply": "Qual?", "options": ["a", "b"]}\n' ;;
  *) printf '{"reply": "%s"}\n' "$1" ;;
esac
