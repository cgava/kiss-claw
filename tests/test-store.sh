#!/bin/bash
# tests/test-store.sh — unit and integration tests for scripts/store.sh
# Pure bash, no external framework. Exit 1 if any test fails.
set -uo pipefail

STORE="$(cd "$(dirname "$0")/.." && pwd)/scripts/store.sh"
TMPDIR_BASE=$(mktemp -d)
export KISS_CLAW_DIR="$TMPDIR_BASE/.kiss-claw"
export KISS_CLAW_AGENTS_DIR="$KISS_CLAW_DIR/agents"
export KISS_CLAW_PROJECT_DIR="$KISS_CLAW_DIR/project"
export KISS_CLAW_SESSIONS_DIR="$KISS_CLAW_DIR/sessions"
export KISS_CLAW_SESSION="test-session-01"

mkdir -p "$KISS_CLAW_AGENTS_DIR" "$KISS_CLAW_PROJECT_DIR" "$KISS_CLAW_SESSIONS_DIR/$KISS_CLAW_SESSION"

PASS=0
FAIL=0

cleanup() { rm -rf "$TMPDIR_BASE"; }
trap cleanup EXIT

assert_eq() {
  local label="$1" expected="$2" actual="$3"
  if [[ "$expected" == "$actual" ]]; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    echo "    expected: $(printf '%q' "$expected")"
    echo "    actual:   $(printf '%q' "$actual")"
    ((FAIL++))
  fi
}

assert_contains() {
  local label="$1" needle="$2" haystack="$3"
  if [[ "$haystack" == *"$needle"* ]]; then
    echo "  PASS: $label"
    ((PASS++))
  else
    echo "  FAIL: $label"
    echo "    expected to contain: $needle"
    echo "    actual:              $haystack"
    ((FAIL++))
  fi
}

assert_exit() {
  local label="$1" expected_code="$2"
  shift 2
  set +e
  "$@" >/dev/null 2>&1
  local code=$?
  set -e
  if [[ "$code" -eq "$expected_code" ]]; then
    echo "  PASS: $label (exit $code)"
    ((PASS++))
  else
    echo "  FAIL: $label (expected exit $expected_code, got $code)"
    ((FAIL++))
  fi
}

SESSION_DIR="$KISS_CLAW_SESSIONS_DIR/$KISS_CLAW_SESSION"

# ---------------------------------------------------------------------------
echo "=== read ==="

out=$(bash "$STORE" read plan)
assert_eq "read missing file returns empty" "" "$out"

echo "hello world" > "$SESSION_DIR/PLAN.md"
out=$(bash "$STORE" read plan)
assert_eq "read existing file returns content" "hello world" "$out"

# ---------------------------------------------------------------------------
echo "=== write ==="

out=$(bash "$STORE" write plan "new content")
assert_eq "write returns ok" "ok" "$out"
content=$(cat "$SESSION_DIR/PLAN.md")
assert_eq "write creates file with content" "new content" "$content"

out=$(bash "$STORE" write plan "overwritten")
content=$(cat "$SESSION_DIR/PLAN.md")
assert_eq "write overwrites existing" "overwritten" "$content"

# ---------------------------------------------------------------------------
echo "=== append ==="

echo "line1" > "$SESSION_DIR/SCRATCH.md"
out=$(bash "$STORE" append scratch "line2")
assert_eq "append returns ok" "ok" "$out"
content=$(cat "$SESSION_DIR/SCRATCH.md")
expected=$(printf 'line1\nline2')
assert_eq "append adds to existing file" "$expected" "$content"

# append to non-existing file
rm -f "$SESSION_DIR/REVIEWS.md"
out=$(bash "$STORE" append reviews "first line")
assert_eq "append to new file returns ok" "ok" "$out"
content=$(cat "$SESSION_DIR/REVIEWS.md")
assert_eq "append creates file if missing" "first line" "$content"

# ---------------------------------------------------------------------------
echo "=== update ==="

cat > "$SESSION_DIR/STATE.md" <<'YAML'
status: "idle"
current_step: "1.0"
blocker: ""
YAML

out=$(bash "$STORE" update state status running)
assert_eq "update returns ok" "ok" "$out"
line=$(grep '^status:' "$SESSION_DIR/STATE.md")
assert_eq "update changes field value" 'status: "running"' "$line"

# update with special chars: /, \, &
bash "$STORE" update state blocker "path/to\\file & more" >/dev/null
line=$(grep '^blocker:' "$SESSION_DIR/STATE.md")
assert_eq "update handles special chars (/ \\ &)" 'blocker: "path/to\file & more"' "$line"

# update non-existing resource file (insights is agent-scoped, no session needed)
set +e
err=$(bash "$STORE" update insights field value 2>&1)
code=$?
set -e
assert_eq "update missing file exits 1" "1" "$code"
assert_contains "update missing file error msg" "resource not found" "$err"

# ---------------------------------------------------------------------------
echo "=== exists ==="

echo "data" > "$SESSION_DIR/PLAN.md"
out=$(bash "$STORE" exists plan)
assert_eq "exists returns true for existing" "true" "$out"

rm -f "$SESSION_DIR/CHECKPOINT.md"
out=$(bash "$STORE" exists checkpoint)
assert_eq "exists returns false for missing" "false" "$out"

# ---------------------------------------------------------------------------
echo "=== list ==="

# Clean slate — only create known files
rm -f "$KISS_CLAW_AGENTS_DIR"/*.md "$KISS_CLAW_PROJECT_DIR"/*.md "$KISS_CLAW_PROJECT_DIR"/*.json "$SESSION_DIR"/*.md
echo "a" > "$SESSION_DIR/PLAN.md"
echo "b" > "$SESSION_DIR/STATE.md"
echo "c" > "$KISS_CLAW_PROJECT_DIR/MEMORY.md"
echo "d" > "$KISS_CLAW_AGENTS_DIR/MEMORY_kiss-orchestrator.md"

out=$(bash "$STORE" list)
assert_contains "list includes plan (session)" "plan" "$out"
assert_contains "list includes state (session)" "state" "$out"
assert_contains "list includes memory (project)" "memory" "$out"
assert_contains "list includes memory:kiss-orchestrator (agents)" "memory:kiss-orchestrator" "$out"

# unknown .md files should be skipped
echo "x" > "$KISS_CLAW_AGENTS_DIR/RANDOM_JUNK.md"
out=$(bash "$STORE" list)
line_count=$(echo "$out" | wc -l)
assert_eq "list skips unknown files (4 entries)" "4" "$line_count"

# ---------------------------------------------------------------------------
echo "=== resource resolution ==="

# Test that each known resource resolves without error
for res in plan state scratch reviews checkpoint; do
  assert_exit "resolve session resource $res succeeds" 0 bash "$STORE" exists "$res"
done

for res in memory memory:kiss-orchestrator memory:kiss-executor insights analyzed; do
  assert_exit "resolve non-session resource $res succeeds" 0 bash "$STORE" exists "$res"
done

# Unknown resource should fail
assert_exit "unknown resource exits 1" 1 bash "$STORE" read "bogus-resource"

# ---------------------------------------------------------------------------
echo "=== file location checks ==="

# Verify files are created in the correct subdirectories
bash "$STORE" write plan "plan content" >/dev/null
assert_eq "plan is in sessions dir" "true" "$(test -f "$SESSION_DIR/PLAN.md" && echo true || echo false)"

bash "$STORE" write state "state content" >/dev/null
assert_eq "state is in sessions dir" "true" "$(test -f "$SESSION_DIR/STATE.md" && echo true || echo false)"

bash "$STORE" write memory "project memory" >/dev/null
assert_eq "memory is in project dir" "true" "$(test -f "$KISS_CLAW_PROJECT_DIR/MEMORY.md" && echo true || echo false)"

bash "$STORE" write "memory:kiss-executor" "agent memory" >/dev/null
assert_eq "memory:kiss-executor is in agents dir" "true" "$(test -f "$KISS_CLAW_AGENTS_DIR/MEMORY_kiss-executor.md" && echo true || echo false)"

bash "$STORE" write insights "insight data" >/dev/null
assert_eq "insights is in agents dir" "true" "$(test -f "$KISS_CLAW_AGENTS_DIR/INSIGHTS.md" && echo true || echo false)"

bash "$STORE" write reviews "review data" >/dev/null
assert_eq "reviews is in sessions dir" "true" "$(test -f "$SESSION_DIR/REVIEWS.md" && echo true || echo false)"

bash "$STORE" write checkpoint "ckpt data" >/dev/null
assert_eq "checkpoint is in sessions dir" "true" "$(test -f "$SESSION_DIR/CHECKPOINT.md" && echo true || echo false)"

# ---------------------------------------------------------------------------
echo "=== session requirement ==="

# Session-scoped resources MUST fail without KISS_CLAW_SESSION
# Use env -u to unset in child process without subshell
for res in plan state reviews scratch checkpoint; do
  set +e
  err=$(env -u KISS_CLAW_SESSION bash "$STORE" read "$res" 2>&1)
  code=$?
  set -e
  assert_eq "$res without session exits non-zero" "1" "$code"
  assert_contains "$res error mentions KISS_CLAW_SESSION" "KISS_CLAW_SESSION" "$err"
done

# Non-session resources should work without KISS_CLAW_SESSION
for res in memory memory:kiss-orchestrator insights analyzed; do
  assert_exit "$res without session succeeds" 0 env -u KISS_CLAW_SESSION bash "$STORE" exists "$res"
done

# ---------------------------------------------------------------------------
echo "=== error cases ==="

# Missing action
assert_exit "no args exits 1" 1 bash "$STORE"

# Unknown action
assert_exit "unknown action exits 1" 1 bash "$STORE" delete plan

# Missing resource for actions that require one
for act in read write append update exists; do
  assert_exit "$act without resource exits 1" 1 bash "$STORE" "$act"
done

# update without field
assert_exit "update without field exits 1" 1 bash "$STORE" update state

# ---------------------------------------------------------------------------
echo ""
echo "=== RESULTS ==="
echo "  passed: $PASS"
echo "  failed: $FAIL"
echo ""
[[ "$FAIL" -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
