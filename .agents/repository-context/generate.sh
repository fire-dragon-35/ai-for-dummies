#!/bin/sh
root=$(git rev-parse --show-toplevel) || exit 1
cd "$root" || exit 1
git ls-files -z --cached --others --exclude-standard | tr '\0' '\n' | grep -v '^\.agents/' | awk -F/ '
  NF == 1 { print; next }
  { p = ""; for (i = 1; i < NF; i++) { p = p $i "\001"; print p } }
' | LC_ALL=C sort -u | awk -F'\001' '
  BEGIN { print "# Repository structure\n" }
  NF == 1 { print; next }
  { s = ""; for (i = 2; i < NF; i++) s = s "  "
    print s $(NF - 1) "/" }
' > .agents/repository-context/directories.md
