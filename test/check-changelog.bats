#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../src/scripts/check-changelog.sh"
  TMP=$(mktemp -d)
  cd "$TMP"
}

teardown() {
  cd /
  rm -rf "$TMP"
}

@test "passes when the heading for the version is present" {
  printf '# Changelog\n\n## [1.2.3] - 2026-08-17\n- did stuff\n' > CHANGELOG.md
  run "$SCRIPT" CHANGELOG.md '## \[{version}\]' 1.2.3
  [ "$status" -eq 0 ]
}

@test "fails when the heading for the version is absent" {
  printf '# Changelog\n\n## [1.2.2]\n- older\n' > CHANGELOG.md
  run "$SCRIPT" CHANGELOG.md '## \[{version}\]' 1.2.3
  [ "$status" -ne 0 ]
}

@test "fails clearly when the changelog file doesn't exist" {
  run "$SCRIPT" CHANGELOG.md '## \[{version}\]' 1.2.3
  [ "$status" -ne 0 ]
  [[ "$output" == *"changelog not found"* ]]
}

@test "escapes regex metacharacters in the version" {
  # A version containing a literal dot must not match an unrelated heading
  # via "." acting as a regex wildcard.
  printf '## [1x2x3]\n' > CHANGELOG.md
  run "$SCRIPT" CHANGELOG.md '## \[{version}\]' 1.2.3
  [ "$status" -ne 0 ]
}

@test "supports a custom heading pattern" {
  printf '# Release 1.2.3\n' > CHANGELOG.md
  run "$SCRIPT" CHANGELOG.md '# Release {version}' 1.2.3
  [ "$status" -eq 0 ]
}
