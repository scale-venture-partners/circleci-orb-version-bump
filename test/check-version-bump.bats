#!/usr/bin/env bats

load test_helper.bash

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../src/scripts/check-version-bump.sh"
  setup_git_repo
}

teardown() {
  teardown_git_repo
}

seed_pyproject_with_changelog() {
  printf '[project]\nname = "foo"\nversion = "%s"\n' "$1" > pyproject.toml
  printf '# Changelog\n\n## [%s]\n- init\n' "$1" > CHANGELOG.md
  commit_all init
  push_main
}

@test "fails when the version was not bumped" {
  seed_pyproject_with_changelog 1.0.0
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"was not bumped"* ]]
}

@test "passes when bumped and the changelog documents it" {
  seed_pyproject_with_changelog 1.0.0
  sed -i.bak 's/1.0.0/1.1.0/' pyproject.toml
  printf '\n## [1.1.0]\n- did stuff\n' >> CHANGELOG.md
  commit_all bump
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"OK (bumped 1.0.0 -> 1.1.0)"* ]]
}

@test "fails when bumped but the changelog wasn't updated" {
  seed_pyproject_with_changelog 1.0.0
  sed -i.bak 's/1.0.0/1.2.0/' pyproject.toml
  commit_all "bump, no changelog"
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"CHANGELOG.md has no heading"* ]]
}

@test "require-changelog=false skips the changelog check" {
  printf '[project]\nname = "foo"\nversion = "1.0.0"\n' > pyproject.toml
  commit_all init
  push_main
  printf '[project]\nname = "foo"\nversion = "1.1.0"\n' > pyproject.toml
  commit_all bump
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main REQUIRE_CHANGELOG=false run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "exempt-paths skips the check entirely for a docs-only diff" {
  seed_pyproject_with_changelog 1.0.0
  mkdir docs
  printf 'guide\n' > docs/guide.md
  commit_all "docs only, no bump"
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main EXEMPT_PATHS="docs/*" run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"skipping"* ]]
}

@test "require-increase=true fails a version decrease" {
  seed_pyproject_with_changelog 1.0.0
  printf '[project]\nname = "foo"\nversion = "0.9.0"\n' > pyproject.toml
  commit_all decrease
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main REQUIRE_CHANGELOG=false REQUIRE_INCREASE=true run "$SCRIPT"
  [ "$status" -ne 0 ]
  [[ "$output" == *"is not greater than"* ]]
}

@test "require-increase=false (default) allows a version decrease" {
  seed_pyproject_with_changelog 1.0.0
  printf '[project]\nname = "foo"\nversion = "0.9.0"\n' > pyproject.toml
  commit_all decrease
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main REQUIRE_CHANGELOG=false run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "passes without comparison when the manifest is new on this branch" {
  printf 'placeholder\n' > README.md
  commit_all init
  push_main
  printf '[project]\nname = "foo"\nversion = "0.1.0"\n' > pyproject.toml
  commit_all "add pyproject"
  MANIFEST_TYPE=python-pyproject BASE_BRANCH=main REQUIRE_CHANGELOG=false run "$SCRIPT"
  [ "$status" -eq 0 ]
  [[ "$output" == *"doesn't exist on origin/main yet"* ]]
}

@test "node-package-json manifest type works end to end" {
  printf '{"name": "foo", "version": "1.0.0"}' > package.json
  printf '# Changelog\n\n## [1.0.0]\n' > CHANGELOG.md
  commit_all init
  push_main
  printf '{"name": "foo", "version": "1.0.1"}' > package.json
  printf '\n## [1.0.1]\n' >> CHANGELOG.md
  commit_all bump
  MANIFEST_TYPE=node-package-json BASE_BRANCH=main run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "defaults manifest-path from manifest-type when unset" {
  seed_pyproject_with_changelog 1.0.0
  sed -i.bak 's/1.0.0/1.0.1/' pyproject.toml
  printf '\n## [1.0.1]\n' >> CHANGELOG.md
  commit_all bump
  MANIFEST_TYPE=python-pyproject MANIFEST_PATH= BASE_BRANCH=main run "$SCRIPT"
  [ "$status" -eq 0 ]
}

@test "supports a nested manifest-path" {
  mkdir backend
  printf '[project]\nname = "foo"\nversion = "1.0.0"\n' > backend/pyproject.toml
  printf '# Changelog\n\n## [1.0.0]\n' > CHANGELOG.md
  commit_all init
  push_main
  printf '[project]\nname = "foo"\nversion = "1.0.1"\n' > backend/pyproject.toml
  printf '\n## [1.0.1]\n' >> CHANGELOG.md
  commit_all bump
  MANIFEST_TYPE=python-pyproject MANIFEST_PATH=backend/pyproject.toml BASE_BRANCH=main run "$SCRIPT"
  [ "$status" -eq 0 ]
}
