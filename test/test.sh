#!/usr/bin/env bash
# End-to-end tests for cloudsync. Run: bash test/test.sh (or make test)
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SYNC="${CLOUDSYNC_BIN:-$REPO_DIR/cloudsync}"
S="$(mktemp -d "${TMPDIR:-/tmp}/cloudsync-test.XXXXXX")"
trap 'rm -rf "$S"' EXIT

PASS=0
FAIL=0
ok()   { PASS=$((PASS+1)); echo "  ✓ $1"; }
fail() { FAIL=$((FAIL+1)); echo "  ✗ $1"; }
check() {
  local desc="$1"
  shift
  if "$@" >/dev/null 2>&1; then ok "$desc"; else fail "$desc"; fi
}
G() { git -C "$1" "${@:2}"; }

export GIT_AUTHOR_NAME=test
export GIT_AUTHOR_EMAIL=t@t
export GIT_COMMITTER_NAME=test
export GIT_COMMITTER_EMAIL=t@t

echo "== setup: bare remote + cloud clone + local worktree =="
REMOTE="$S/remote.git"
CLOUD="$S/cloud"
LOCAL="$S/local"
git init -q --bare "$REMOTE"
git clone -q "$REMOTE" "$CLOUD"
G "$CLOUD" switch -q -c feature
echo "v1" > "$CLOUD/app.txt"
G "$CLOUD" add app.txt
G "$CLOUD" commit -qm init
G "$CLOUD" push -qu origin feature
git clone -q --branch feature "$REMOTE" "$LOCAL"

echo "== version and status =="
check "version prints" bash -c "'$SYNC' version | grep -q '^cloudsync [0-9]'"
cd "$LOCAL"
"$SYNC" status > "$S/status.log" 2>&1
check "status sees current branch" grep -q "state:     current" "$S/status.log"
check "status names upstream" grep -q "origin/feature" "$S/status.log"

echo "== one-shot fast-forward =="
echo "v2" > "$CLOUD/app.txt"
G "$CLOUD" commit -qam remote-v2
G "$CLOUD" push -q
"$SYNC" sync > "$S/sync.log" 2>&1
check "sync updates files" grep -q "^v2$" "$LOCAL/app.txt"
check "sync reports commit count" grep -q "1 commit)" "$S/sync.log"
check "sync preserves branch checkout" bash -c "[ \"\$(git -C '$LOCAL' branch --show-current)\" = feature ]"
check "sync makes local equal remote" bash -c "[ \"\$(git -C '$LOCAL' rev-parse HEAD)\" = \"\$(git -C '$REMOTE' rev-parse feature)\" ]"

echo "== dirty worktree is untouched =="
echo "v3" > "$CLOUD/app.txt"
G "$CLOUD" commit -qam remote-v3
G "$CLOUD" push -q
echo "local edit" > "$LOCAL/local.txt"
before=$(G "$LOCAL" rev-parse HEAD)
"$SYNC" sync > "$S/dirty.log" 2>&1
rc=$?
check "dirty sync exits nonzero" test "$rc" -ne 0
check "dirty sync explains pause" grep -q "local files are dirty" "$S/dirty.log"
check "dirty sync does not move HEAD" bash -c "[ \"\$(git -C '$LOCAL' rev-parse HEAD)\" = '$before' ]"
check "dirty file survives" grep -q "local edit" "$LOCAL/local.txt"
rm "$LOCAL/local.txt"
"$SYNC" sync >/dev/null
check "sync resumes after cleanup" grep -q "^v3$" "$LOCAL/app.txt"

echo "== local-only commit is never sent or overwritten =="
echo "local commit" > "$LOCAL/local.txt"
G "$LOCAL" add local.txt
G "$LOCAL" commit -qm local-only
local_head=$(G "$LOCAL" rev-parse HEAD)
remote_head=$(G "$REMOTE" rev-parse feature)
"$SYNC" sync > "$S/ahead.log" 2>&1
rc=$?
check "ahead sync exits nonzero" test "$rc" -ne 0
check "ahead sync explains pause" grep -q "local commits" "$S/ahead.log"
check "ahead sync leaves local HEAD" bash -c "[ \"\$(git -C '$LOCAL' rev-parse HEAD)\" = '$local_head' ]"
check "ahead sync never pushes" bash -c "[ \"\$(git -C '$REMOTE' rev-parse feature)\" = '$remote_head' ]"

echo "== divergence is untouched =="
echo "v4" > "$CLOUD/app.txt"
G "$CLOUD" commit -qam remote-v4
G "$CLOUD" push -q
"$SYNC" sync > "$S/diverged.log" 2>&1
rc=$?
check "diverged sync exits nonzero" test "$rc" -ne 0
check "diverged sync explains pause" grep -q "histories diverged" "$S/diverged.log"
check "diverged sync leaves local HEAD" bash -c "[ \"\$(git -C '$LOCAL' rev-parse HEAD)\" = '$local_head' ]"

echo "== detached and missing-upstream states are refused =="
DETACHED="$S/detached"
git clone -q --branch feature "$REMOTE" "$DETACHED"
G "$DETACHED" checkout -q --detach
cd "$DETACHED"
"$SYNC" sync > "$S/detached.log" 2>&1
rc=$?
check "detached sync exits nonzero" test "$rc" -ne 0
check "detached sync explains refusal" grep -q "detached HEAD" "$S/detached.log"

NOUP="$S/no-upstream"
git init -q -b local "$NOUP"
echo "x" > "$NOUP/x"
G "$NOUP" add x
G "$NOUP" commit -qm init
cd "$NOUP"
"$SYNC" sync > "$S/noup.log" 2>&1
rc=$?
check "missing upstream exits nonzero" test "$rc" -ne 0
check "missing upstream explains setup" grep -q "has no upstream" "$S/noup.log"

echo "== fetch failures never use stale state =="
FETCH_FAIL="$S/fetch-fail"
git clone -q --branch feature "$REMOTE" "$FETCH_FAIL"
G "$FETCH_FAIL" remote set-url origin "$S/missing.git"
cd "$FETCH_FAIL"
"$SYNC" sync > "$S/fetch-fail.log" 2>&1
rc=$?
check "fetch failure exits nonzero" test "$rc" -ne 0
check "fetch failure explains retry" grep -q "could not fetch 'origin'" "$S/fetch-fail.log"

echo "== watch picks up a later remote commit =="
WATCH_LOCAL="$S/watch-local"
git clone -q --branch feature "$REMOTE" "$WATCH_LOCAL"
cd "$WATCH_LOCAL"
"$SYNC" watch --interval 1 > "$S/watch.log" 2>&1 &
watch_pid=$!
sleep 1
echo "v5-watch" > "$CLOUD/app.txt"
G "$CLOUD" commit -qam remote-v5
G "$CLOUD" push -q
i=0
while [ "$i" -lt 10 ] && ! grep -q "v5-watch" "$WATCH_LOCAL/app.txt"; do
  sleep 1
  i=$((i+1))
done
check "watch updates files" grep -q "v5-watch" "$WATCH_LOCAL/app.txt"
kill "$watch_pid" 2>/dev/null
wait "$watch_pid" 2>/dev/null
check "watch lock is cleaned up" bash -c "! test -d \"\$(git -C '$WATCH_LOCAL' rev-parse --path-format=absolute --git-path cloudsync-watch.lock)\""

cd /
echo
echo "RESULT: $PASS passed, $FAIL failed"
exit "$FAIL"
