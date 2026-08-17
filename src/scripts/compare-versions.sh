#!/bin/sh
# compare-versions.sh <old> <new>
#
# Exit 0 if <new> is greater than <old>, exit 1 otherwise. Compares the
# leading dotted-numeric core of each version (e.g. "1.2.3" out of
# "1.2.3-rc1"); a non-numeric pre-release/build suffix does not affect the
# comparison.
set -eu

old_core=$(printf '%s' "$1" | sed -E 's/^([0-9]+(\.[0-9]+)*).*/\1/')
new_core=$(printf '%s' "$2" | sed -E 's/^([0-9]+(\.[0-9]+)*).*/\1/')

awk -v old="$old_core" -v new="$new_core" '
BEGIN {
  n_old = split(old, o, ".")
  n_new = split(new, n, ".")
  max = (n_old > n_new) ? n_old : n_new
  for (i = 1; i <= max; i++) {
    ov = (i <= n_old) ? o[i] + 0 : 0
    nv = (i <= n_new) ? n[i] + 0 : 0
    if (nv > ov) { exit 0 }
    if (nv < ov) { exit 1 }
  }
  exit 1
}
'
