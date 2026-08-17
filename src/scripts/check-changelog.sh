#!/bin/sh
# check-changelog.sh <changelog-path> <heading-pattern> <version>
#
# Exit 0 if <changelog-path> contains a heading matching <heading-pattern>
# with "{version}" substituted for <version> (regex-escaped). Exit 1
# otherwise, including if the changelog file itself is missing.
set -eu

changelog_path="$1"
heading_pattern="$2"
version="$3"

if [ ! -f "$changelog_path" ]; then
  echo "check-changelog.sh: changelog not found: $changelog_path" >&2
  exit 1
fi

# shellcheck disable=SC2016
escaped_version=$(printf '%s' "$version" | sed 's/[.[\*^$()+?{}|\\]/\\&/g')

# Plain string splitting on the literal "{version}" token, not a sed
# substitution: escaped_version contains backslashes, and sed's replacement
# text treats backslashes specially (backreferences), silently stripping
# them if passed through `s/.../.../`.
prefix="${heading_pattern%%\{version\}*}"
suffix="${heading_pattern#*\{version\}}"
pattern="${prefix}${escaped_version}${suffix}"

grep -qE "$pattern" "$changelog_path"
