#!/bin/sh
# changed-files-exempt.sh <base-branch> <glob> [glob ...]
#
# Exit 0 if every file changed relative to origin/<base-branch> matches at
# least one of the given shell glob patterns (e.g. "docs/*", "*.md",
# ".circleci/*", "Makefile"). Exit 1 if any changed file matches none of
# them (or if no globs were given, or there's nothing to diff against).
set -eu

base_branch="$1"
shift

if [ "$#" -eq 0 ]; then
  exit 1
fi

changed_files=$(git diff --name-only "origin/${base_branch}...HEAD" || true)
if [ -z "$changed_files" ]; then
  exit 0
fi

exempt=1
# Redirecting via a here-doc (rather than piping into the loop) keeps this
# while loop in the current shell, so `exempt`/`break` below actually take
# effect — piping in would run it in a subshell instead.
while IFS= read -r file; do
  [ -z "$file" ] && continue
  file_exempt=0
  for glob in "$@"; do
    # shellcheck disable=SC2254 # intentionally unquoted: this is a glob pattern
    case "$file" in
      $glob) file_exempt=1 ;;
    esac
    [ "$file_exempt" -eq 1 ] && break
  done
  if [ "$file_exempt" -eq 0 ]; then
    exempt=0
    break
  fi
done <<EOF
$changed_files
EOF

[ "$exempt" -eq 1 ]
