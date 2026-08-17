#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../src/scripts/get-version.sh"
  TMP=$(mktemp -d)
  cd "$TMP"
}

teardown() {
  cd /
  rm -rf "$TMP"
}

@test "python-pyproject: reads a PEP 621 [project] version" {
  printf '[project]\nname = "foo"\nversion = "1.2.3"\n' > pyproject.toml
  run "$SCRIPT" python-pyproject pyproject.toml
  [ "$status" -eq 0 ]
  [ "$output" = "1.2.3" ]
}

@test "python-pyproject: reads a [tool.poetry] version" {
  printf '[tool.poetry]\nname = "foo"\nversion = "2.0.0"\n' > pyproject.toml
  run "$SCRIPT" python-pyproject pyproject.toml
  [ "$status" -eq 0 ]
  [ "$output" = "2.0.0" ]
}

@test "python-pyproject: reads a bare top-level version as a last resort" {
  printf 'version = "0.0.1"\n' > pyproject.toml
  run "$SCRIPT" python-pyproject pyproject.toml
  [ "$status" -eq 0 ]
  [ "$output" = "0.0.1" ]
}

@test "python-pyproject: fails clearly when no version key exists" {
  printf '[project]\nname = "foo"\n' > pyproject.toml
  run "$SCRIPT" python-pyproject pyproject.toml
  [ "$status" -ne 0 ]
  [[ "$output" == *"no [project].version"* ]]
}

@test "node-package-json: reads the top-level version field" {
  printf '{"name": "foo", "version": "3.4.5"}' > package.json
  run "$SCRIPT" node-package-json package.json
  [ "$status" -eq 0 ]
  [ "$output" = "3.4.5" ]
}

@test "node-package-json: fails clearly when version is missing" {
  printf '{"name": "foo"}' > package.json
  run "$SCRIPT" node-package-json package.json
  [ "$status" -ne 0 ]
  [[ "$output" == *"no .version field"* ]]
}

@test "generic: extracts the version via a capture-group pattern" {
  printf 'build-v9.9.9-final\n' > VERSION.txt
  run "$SCRIPT" generic VERSION.txt 'v([0-9]+\.[0-9]+\.[0-9]+)'
  [ "$status" -eq 0 ]
  [ "$output" = "9.9.9" ]
}

@test "generic: requires a version-pattern" {
  printf 'v1.0.0\n' > VERSION.txt
  run "$SCRIPT" generic VERSION.txt
  [ "$status" -ne 0 ]
  [[ "$output" == *"version-pattern is required"* ]]
}

@test "generic: fails clearly when the pattern matches nothing" {
  printf 'no version here\n' > VERSION.txt
  run "$SCRIPT" generic VERSION.txt 'v([0-9]+\.[0-9]+\.[0-9]+)'
  [ "$status" -ne 0 ]
  [[ "$output" == *"matched nothing"* ]]
}

@test "fails clearly when the manifest file doesn't exist" {
  run "$SCRIPT" python-pyproject nope.toml
  [ "$status" -ne 0 ]
  [[ "$output" == *"manifest not found"* ]]
}

@test "fails clearly for an unknown manifest-type" {
  printf 'x\n' > f.txt
  run "$SCRIPT" cobol f.txt
  [ "$status" -ne 0 ]
  [[ "$output" == *"unknown manifest-type"* ]]
}
