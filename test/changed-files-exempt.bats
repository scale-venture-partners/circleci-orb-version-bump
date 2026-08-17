#!/usr/bin/env bats

load test_helper.bash

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../src/scripts/changed-files-exempt.sh"
  setup_git_repo
  printf 'base\n' > pyproject.toml
  mkdir docs
  printf 'guide\n' > docs/guide.md
  printf 'readme\n' > README.md
  commit_all init
  push_main
}

teardown() {
  teardown_git_repo
}

@test "exempt when every changed file matches a glob" {
  printf 'updated\n' > docs/guide.md
  printf 'updated\n' > README.md
  commit_all "docs only"
  run "$SCRIPT" main "docs/*" "*.md"
  [ "$status" -eq 0 ]
}

@test "not exempt when a non-matching file also changed" {
  printf 'updated\n' > docs/guide.md
  printf 'changed\n' >> pyproject.toml
  commit_all "docs and code"
  run "$SCRIPT" main "docs/*" "*.md"
  [ "$status" -ne 0 ]
}

@test "an exact filename glob matches only that file" {
  printf 'updated\n' > README.md
  commit_all "readme only"
  run "$SCRIPT" main "README.md"
  [ "$status" -eq 0 ]
}

@test "not exempt with no glob patterns given" {
  printf 'updated\n' > README.md
  commit_all "readme only"
  run "$SCRIPT" main
  [ "$status" -ne 0 ]
}

@test "exempt when there is no diff at all against base" {
  run "$SCRIPT" main "docs/*"
  [ "$status" -eq 0 ]
}
