# AGENTS.md's comment rule: a line, or a short block of up to four for a contract, so a fifth comment line in a row fails.
{ pkgs, self }:
pkgs.runCommand "quick-key-comments" { } ''
  cd ${self}
  status=0
  for file in $(find . -type f \( -name '*.qml' -o -name '*.nix' -o -name '*.sh' -o -name '*.nu' -o -name '*.js' -o -name '*.py' \) | sort); do
    case $file in *.qml | *.js) marker='//' ;; *) marker='#' ;; esac
    awk -v marker="$marker" -v file="$file" '
      { comment = index($0, marker) && substr($0, match($0, /[^ \t]/), length(marker)) == marker && $0 !~ /^#!/ }
      { run = comment ? run + 1 : 0 }
      run == 5 { print file ":" NR ": a comment over four lines"; failed = 1 }
      END { exit failed }
    ' "$file" || status=1
  done
  if [ $status -ne 0 ]; then exit 1; fi
  touch $out
''
