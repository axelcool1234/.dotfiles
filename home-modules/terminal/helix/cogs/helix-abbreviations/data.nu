http get https://raw.githubusercontent.com/leanprover/vscode-lean4/refs/heads/master/lean4-unicode-input/src/abbreviations.json
  | transpose
  | rename key val
  | insert len {$in.key | str length}
  | sort-by len
  | where key != "\\"
  | where val !~ '\$CURSOR'
  | each {$"  \(list ($in.key | to json) ($in.val | to json)\)"}
  | str join "\n"
  | $"\(provide abbrev-pairs)\n\(define abbrev-pairs \(list\n($in)\n\)\)"
  | save data.scm

