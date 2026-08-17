#!/bin/sh
# check-version-bump.sh
#
# Orchestrates the full version-bump check using the sibling scripts in this
# directory. Inputs come from environment variables, set by the orb
# command's `environment:` block from its parameters:
#
#   MANIFEST_TYPE              python-pyproject | node-package-json | generic
#   MANIFEST_PATH              path to the manifest file (default per type)
#   VERSION_PATTERN            only for manifest-type=generic
#   BASE_BRANCH                default: main
#   REQUIRE_CHANGELOG          "true" | "false"
#   CHANGELOG_PATH             default: CHANGELOG.md
#   CHANGELOG_HEADING_PATTERN  default: "## \[{version}\]"
#   EXEMPT_PATHS               comma-separated shell glob patterns
#   REQUIRE_INCREASE           "true" | "false"
set -eu

script_dir=$(cd -- "$(dirname -- "$0")" && pwd)

# shellcheck disable=SC2153
manifest_type="$MANIFEST_TYPE"
manifest_path="${MANIFEST_PATH:-}"
base_branch="${BASE_BRANCH:-main}"
require_changelog="${REQUIRE_CHANGELOG:-true}"
changelog_path="${CHANGELOG_PATH:-CHANGELOG.md}"
# Not folded into a single ${VAR:-default} expansion: the default text
# itself contains literal { } characters, which is genuinely ambiguous for
# the shell to brace-match inside parameter-expansion syntax.
changelog_heading_pattern="${CHANGELOG_HEADING_PATTERN:-}"
if [ -z "$changelog_heading_pattern" ]; then
  changelog_heading_pattern='## \[{version}\]'
fi
require_increase="${REQUIRE_INCREASE:-false}"
exempt_paths="${EXEMPT_PATHS:-}"

if [ -z "$manifest_path" ]; then
  case "$manifest_type" in
    python-pyproject) manifest_path="pyproject.toml" ;;
    node-package-json) manifest_path="package.json" ;;
    *)
      echo "check-version-bump: manifest-path is required for manifest-type=${manifest_type}" >&2
      exit 1
      ;;
  esac
fi

git fetch --quiet origin "$base_branch"

if [ -n "$exempt_paths" ]; then
  old_ifs=$IFS
  IFS=','
  # shellcheck disable=SC2086
  set -- $exempt_paths
  IFS=$old_ifs
  if "$script_dir/changed-files-exempt.sh" "$base_branch" "$@"; then
    echo "check-version-bump: diff is fully within exempt paths — skipping."
    exit 0
  fi
fi

new_version=$("$script_dir/get-version.sh" "$manifest_type" "$manifest_path" "${VERSION_PATTERN:-}")

base_manifest=$(mktemp)
trap 'rm -f "$base_manifest"' EXIT
if ! git show "origin/${base_branch}:${manifest_path}" > "$base_manifest" 2>/dev/null; then
  echo "check-version-bump: ${manifest_path} doesn't exist on origin/${base_branch} yet — nothing to compare against."
  exit 0
fi
old_version=$("$script_dir/get-version.sh" "$manifest_type" "$base_manifest" "${VERSION_PATTERN:-}")

echo "check-version-bump: ${base_branch}=${old_version} branch=${new_version}"

if [ "$old_version" = "$new_version" ]; then
  echo "check-version-bump: version was not bumped (still ${new_version})." >&2
  exit 1
fi

if [ "$require_increase" = "true" ]; then
  if ! "$script_dir/compare-versions.sh" "$old_version" "$new_version"; then
    echo "check-version-bump: ${new_version} is not greater than ${old_version}." >&2
    exit 1
  fi
fi

if [ "$require_changelog" = "true" ]; then
  if ! "$script_dir/check-changelog.sh" "$changelog_path" "$changelog_heading_pattern" "$new_version"; then
    echo "check-version-bump: ${changelog_path} has no heading matching '${changelog_heading_pattern}' for version ${new_version}." >&2
    exit 1
  fi
fi

echo "check-version-bump: OK (bumped ${old_version} -> ${new_version})."
