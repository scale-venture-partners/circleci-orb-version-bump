#!/bin/sh
# check-version-bump.sh
#
# `circleci orb pack` inlines this file verbatim into the published orb, so
# it must not shell out to sibling files — those don't exist at runtime in
# the packed artifact. get-version.sh/compare-versions.sh/check-changelog.sh/
# changed-files-exempt.sh are thin wrappers that source this file (with
# VERSION_BUMP_LIB_ONLY=1) to reuse these functions for direct/bats
# invocation without duplicating their logic.
#
# When run standalone (as the orb's `check` command), inputs come from
# environment variables set by the orb command's `environment:` block:
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

get_version() {
  manifest_type="$1"
  manifest_path="$2"
  version_pattern="${3:-}"

  if [ ! -f "$manifest_path" ]; then
    echo "get-version.sh: manifest not found: $manifest_path" >&2
    exit 1
  fi

  case "$manifest_type" in
    python-pyproject)
      python3 - "$manifest_path" <<'PYEOF'
import sys
import tomllib

path = sys.argv[1]
with open(path, "rb") as f:
    data = tomllib.load(f)

version = data.get("project", {}).get("version")
if version is None:
    version = data.get("tool", {}).get("poetry", {}).get("version")
if version is None:
    version = data.get("version")
if version is None:
    sys.stderr.write(
        f"get-version.sh: no [project].version, [tool.poetry].version, "
        f"or top-level version in {path}\n"
    )
    sys.exit(1)
print(version)
PYEOF
      ;;
    node-package-json)
      node -e '
        const fs = require("fs");
        const data = JSON.parse(fs.readFileSync(process.argv[1], "utf8"));
        if (typeof data.version !== "string") {
          process.stderr.write("get-version.sh: no .version field in " + process.argv[1] + "\n");
          process.exit(1);
        }
        console.log(data.version);
      ' "$manifest_path"
      ;;
    generic)
      if [ -z "$version_pattern" ]; then
        echo "get-version.sh: version-pattern is required for manifest-type=generic" >&2
        exit 1
      fi
      result=$(sed -nE "s/.*${version_pattern}.*/\1/p" "$manifest_path" | head -n1)
      if [ -z "$result" ]; then
        echo "get-version.sh: version-pattern matched nothing in $manifest_path" >&2
        exit 1
      fi
      echo "$result"
      ;;
    *)
      echo "get-version.sh: unknown manifest-type: $manifest_type" >&2
      exit 1
      ;;
  esac
}

compare_versions() {
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
}

check_changelog() {
  cc_path="$1"
  heading_pattern="$2"
  version="$3"

  if [ ! -f "$cc_path" ]; then
    echo "check-changelog.sh: changelog not found: $cc_path" >&2
    return 1
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

  grep -qE "$pattern" "$cc_path"
}

changed_files_exempt() {
  cfe_branch="$1"
  shift

  if [ "$#" -eq 0 ]; then
    return 1
  fi

  changed_files=$(git diff --name-only "origin/${cfe_branch}...HEAD" || true)
  if [ -z "$changed_files" ]; then
    return 0
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
}

main() {
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
    if changed_files_exempt "$base_branch" "$@"; then
      echo "check-version-bump: diff is fully within exempt paths — skipping."
      exit 0
    fi
  fi

  new_version=$(get_version "$manifest_type" "$manifest_path" "${VERSION_PATTERN:-}")

  base_manifest=$(mktemp)
  trap 'rm -f "$base_manifest"' EXIT
  if ! git show "origin/${base_branch}:${manifest_path}" > "$base_manifest" 2>/dev/null; then
    echo "check-version-bump: ${manifest_path} doesn't exist on origin/${base_branch} yet — nothing to compare against."
    exit 0
  fi
  old_version=$(get_version "$manifest_type" "$base_manifest" "${VERSION_PATTERN:-}")

  echo "check-version-bump: ${base_branch}=${old_version} branch=${new_version}"

  if [ "$old_version" = "$new_version" ]; then
    echo "check-version-bump: version was not bumped (still ${new_version})." >&2
    exit 1
  fi

  if [ "$require_increase" = "true" ]; then
    if ! compare_versions "$old_version" "$new_version"; then
      echo "check-version-bump: ${new_version} is not greater than ${old_version}." >&2
      exit 1
    fi
  fi

  if [ "$require_changelog" = "true" ]; then
    if ! check_changelog "$changelog_path" "$changelog_heading_pattern" "$new_version"; then
      echo "check-version-bump: ${changelog_path} has no heading matching '${changelog_heading_pattern}' for version ${new_version}." >&2
      exit 1
    fi
  fi

  echo "check-version-bump: OK (bumped ${old_version} -> ${new_version})."
}

if [ "${VERSION_BUMP_LIB_ONLY:-0}" != "1" ]; then
  main
fi
