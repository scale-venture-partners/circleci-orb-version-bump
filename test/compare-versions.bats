#!/usr/bin/env bats

setup() {
  SCRIPT="$BATS_TEST_DIRNAME/../src/scripts/compare-versions.sh"
}

@test "new patch > old patch" {
  run "$SCRIPT" 1.2.3 1.2.4
  [ "$status" -eq 0 ]
}

@test "equal versions are not an increase" {
  run "$SCRIPT" 1.2.3 1.2.3
  [ "$status" -eq 1 ]
}

@test "new < old is not an increase" {
  run "$SCRIPT" 1.2.3 1.2.2
  [ "$status" -eq 1 ]
}

@test "numeric comparison, not lexicographic (1.10.0 > 1.9.0)" {
  run "$SCRIPT" 1.9.0 1.10.0
  [ "$status" -eq 0 ]
}

@test "a pre-release suffix doesn't count as an increase over its own core" {
  run "$SCRIPT" 1.2.3 1.2.3-rc1
  [ "$status" -eq 1 ]
}

@test "different segment counts are padded with zero" {
  run "$SCRIPT" 1.2 1.2.1
  [ "$status" -eq 0 ]
  run "$SCRIPT" 1.2.0 1.2
  [ "$status" -eq 1 ]
}

@test "major version increase" {
  run "$SCRIPT" 1.9.9 2.0.0
  [ "$status" -eq 0 ]
}
