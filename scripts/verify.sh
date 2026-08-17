#!/bin/sh
# Runs everything: shellcheck, bats tests, orb packing, and orb validation.
set -eu
cd "$(git rev-parse --show-toplevel)"

echo "==> shellcheck"
shellcheck -s sh src/scripts/*.sh

echo "==> bats"
bats test/

echo "==> circleci orb pack"
circleci orb pack src > orb.yml

echo "==> circleci orb validate"
circleci orb validate orb.yml

echo "All checks passed."
