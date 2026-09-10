#!/bin/sh
# compare-versions.sh <old> <new>
#
# Thin wrapper over check-version-bump.sh's compare_versions(), the single
# source of truth (see that file for why logic lives there, not here).
set -eu
# shellcheck disable=SC2034  # read by the sourced file below
VERSION_BUMP_LIB_ONLY=1
# shellcheck disable=SC1091
. "$(cd -- "$(dirname -- "$0")" && pwd)/check-version-bump.sh"
compare_versions "$@"
