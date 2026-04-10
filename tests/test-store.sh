#!/bin/bash
# tests/test-store.sh — unit and integration tests for scripts/store.sh
# Pure bash, no external framework. Exit 1 if any test fails.
set -uo pipefail

STORE="$(cd "$(dirname "$0")/.." && pwd)/scripts/store.sh"
TMPDIR_BASE=$(mktemp -d)
export KISS_CLAW_DIR="$TMPDIR_BASE/.kiss-claw"
mkdir -p "$KISS_CLAW_DIR"

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

# ---------------------------------------------------------------------------
echo "=== read ==="

out=$(bash "$STORE" read plan)
assert_eq "read missing file returns empty" "" "$out"

echo "hello world" > "$KISS_CLAW_DIR/PLAN.md"
out=$(bash "$STORE" read plan)
assert_eq "read existing file returns content" "hello world" "$out"

# ---------------------------------------------------------------------------
echo "=== write ==="

out=$(bash "$STORE" write plan "new content")
assert_eq "write returns ok" "ok" "$out"
content=$(cat "$KISS_CLAW_DIR/PLAN.md")
assert_eq "write creates file with content" "new content" "$content"

out=$(bash "$STORE" write plan "overwritten")
content=$(cat "$KISS_CLAW_DIR/PLAN.md")
assert_eq "write overwrites existing" "overwritten" "$content"

# ---------------------------------------------------------------------------
echo "=== append ==="

echo "line1" > "$KISS_CLAW_DIR/SCRATCH.md"
out=$(bash "$STORE" append scratch "line2")
assert_eq "append returns ok" "ok" "$out"
content=$(cat "$KISS_CLAW_DIR/SCRATCH.md")
expected=$(printf 'line1\nline2')
assert_eq "append adds to existing file" "$expected" "$content"

# append to non-existing file
rm -f "$KISS_CLAW_DIR/REVIEWS.md"
out=$(bash "$STORE" append reviews "first line")
assert_eq "append to new file returns ok" "ok" "$out"
content=$(cat "$KISS_CLAW_DIR/REVIEWS.md")
assert_eq "append creates file if missing" "first line" "$content"

# ---------------------------------------------------------------------------
echo "=== update ==="

cat > "$KISS_CLAW_DIR/STATE.md" <<'YAML'
status: "idle"
current_step: "1.0"
blocker: ""
YAML

out=$(bash "$STORE" update state status running)
assert_eq "update returns ok" "ok" "$out"
line=$(grep '^status:' "$KISS_CLAW_DIR/STATE.md")
assert_eq "update changes field value" 'status: "running"' "$line"

# update with special chars: /, \, &
bash "$STORE" update state blocker "path/to\\file & more" >/dev/null
line=$(grep '^blocker:' "$KISS_CLAW_DIR/STATE.md")
assert_eq "update handles special chars (/ \\ &)" 'blocker: "path/to\file & more"' "$line"

# update non-existing resource file
set +e
err=$(bash "$STORE" update insights field value 2>&1)
code=$?
set -e
assert_eq "update missing file exits 1" "1" "$code"
assert_contains "update missing file error msg" "resource not found" "$err"

# ---------------------------------------------------------------------------
echo "=== exists ==="

echo "data" > "$KISS_CLAW_DIR/PLAN.md"
out=$(bash "$STORE" exists plan)
assert_eq "exists returns true for existing" "true" "$out"

rm -f "$KISS_CLAW_DIR/CHECKPOINT.md"
out=$(bash "$STORE" exists checkpoint)
assert_eq "exists returns false for missing" "false" "$out"

# ---------------------------------------------------------------------------
echo "=== list ==="

# Clean slate — only create known files
rm -f "$KISS_CLAW_DIR"/*.md
echo "a" > "$KISS_CLAW_DIR/PLAN.md"
echo "b" > "$KISS_CLAW_DIR/STATE.md"
echo "c" > "$KISS_CLAW_DIR/MEMORY.md"
echo "d" > "$KISS_CLAW_DIR/MEMORY_orchestrator.md"

out=$(bash "$STORE" list)
assert_contains "list includes plan" "plan" "$out"
assert_contains "list includes state" "state" "$out"
assert_contains "list includes memory" "memory" "$out"
assert_contains "list includes memory:orchestrator" "memory:orchestrator" "$out"

# unknown .md files should be skipped
echo "x" > "$KISS_CLAW_DIR/RANDOM_JUNK.md"
out=$(bash "$STORE" list)
line_count=$(echo "$out" | wc -l)
assert_eq "list skips unknown files (4 entries)" "4" "$line_count"

# ---------------------------------------------------------------------------
echo "=== resource resolution ==="

# Test that each known resource resolves without error
for res in plan state scratch memory memory:orchestrator memory:executor \
           reviews insights analyzed token-stats checkpoint; do
  assert_exit "resolve $res succeeds" 0 bash "$STORE" exists "$res"
done

# Unknown resource should fail
assert_exit "unknown resource exits 1" 1 bash "$STORE" read "bogus-resource"

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
