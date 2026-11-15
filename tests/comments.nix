# AGENTS.md's comment rule: one line, so two comment lines in a row fail.
{ pkgs, self }:
pkgs.runCommand "quick-key-comments" { } ''
  cd ${self}
  status=0
  for file in $(find . -type f \( -name '*.qml' -o -name '*.nix' -o -name '*.sh' -o -name '*.nu' \) | sort); do
    case $file in *.qml) marker='//' ;; *) marker='#' ;; esac
    awk -v marker="$marker" -v file="$file" '
      { comment = index($0, marker) && substr($0, match($0, /[^ \t]/), length(marker)) == marker && $0 !~ /^#!/ }
      comment && previous { print file ":" NR ": a comment over one line"; failed = 1 }
      { previous = comment }
      END { exit failed }
    ' "$file" || status=1
  done
  if [ $status -ne 0 ]; then exit 1; fi
  touch $out
''
