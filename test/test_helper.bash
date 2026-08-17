# Shared bats test helpers.

# Creates a bare "origin" repo plus a working clone with one commit on
# `main`, and cd's into the clone. Sets ORIGIN_DIR and WORK_DIR.
setup_git_repo() {
  REPO_TMP=$(mktemp -d)
  ORIGIN_DIR="$REPO_TMP/origin.git"
  WORK_DIR="$REPO_TMP/work"
  git init -q --bare --initial-branch=main "$ORIGIN_DIR"
  git clone -q "$ORIGIN_DIR" "$WORK_DIR"
  cd "$WORK_DIR" || return 1
  git config user.name test
  git config user.email test@example.com
}

commit_all() {
  git add -A
  git commit -q -m "$1"
}

push_main() {
  git push -q origin main
}

teardown_git_repo() {
  cd / || return 0
  [ -n "${REPO_TMP:-}" ] && rm -rf "$REPO_TMP"
}
