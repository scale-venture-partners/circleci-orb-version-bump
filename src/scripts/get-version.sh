#!/bin/sh
# get-version.sh <manifest-type> <manifest-path> [version-pattern]
#
# Prints the version string found in <manifest-path> to stdout, or exits
# non-zero with an error on stderr if it can't be found.
set -eu

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
