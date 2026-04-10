#!/bin/bash
# tests/test-e2e.sh — end-to-end test for kiss-claw persistence layer
# Validates the full lifecycle: init -> plan -> execute -> review -> improve -> checkpoint
# Also validates guard.sh protection. Pure bash, no external framework. Exit 1 if any fail.
set -uo pipefail

REPO_DIR="$(cd "$(dirname "$0")/.." && pwd)"
STORE="$REPO_DIR/scripts/store.sh"
GUARD="$REPO_DIR/hooks/guard.sh"
SESSION_END="$REPO_DIR/hooks/session-end.sh"
INIT="$REPO_DIR/scripts/init.sh"

TMPDIR_BASE=$(mktemp -d)
export KISS_CLAW_DIR="$TMPDIR_BASE/.kiss-claw"

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

# ===========================================================================
echo "=== Phase 1: Init ==="
# ===========================================================================

# Run init.sh with KISS_CLAW_DIR pointing to temp
(cd "$TMPDIR_BASE" && bash "$INIT")

# Verify memory files were created via store.sh exists
out=$(bash "$STORE" exists memory)
assert_eq "init creates MEMORY.md" "true" "$out"

out=$(bash "$STORE" exists "memory:kiss-orchestrator")
assert_eq "init creates MEMORY_kiss-orchestrator.md" "true" "$out"

out=$(bash "$STORE" exists "memory:kiss-executor")
assert_eq "init creates MEMORY_kiss-executor.md" "true" "$out"

out=$(bash "$STORE" exists "memory:kiss-verificator")
assert_eq "init creates MEMORY_kiss-verificator.md" "true" "$out"

out=$(bash "$STORE" exists "memory:kiss-improver")
assert_eq "init creates MEMORY_kiss-improver.md" "true" "$out"

# ===========================================================================
echo ""
echo "=== Phase 2: Plan ==="
# ===========================================================================

# Write a test plan via store.sh
out=$(bash "$STORE" write plan "# Test Plan
## Phase 1
- Step 1.1: Do the thing
- Step 1.2: Verify the thing")
assert_eq "write plan returns ok" "ok" "$out"

# Write initial state via store.sh
out=$(bash "$STORE" write state 'project: "e2e-test"
current_phase: "Phase 1"
current_step: "1.1"
status: "ready"
blocker: ""
completed: []
mode: "live"
updated: "2026-04-10"

log:
  - "2026-04-10 - plan created"')
assert_eq "write state returns ok" "ok" "$out"

# Verify plan content
plan_content=$(bash "$STORE" read plan)
assert_contains "plan contains Phase 1" "Phase 1" "$plan_content"

state_content=$(bash "$STORE" read state)
assert_contains "state has correct project" "e2e-test" "$state_content"

# ===========================================================================
echo ""
echo "=== Phase 3: Execute ==="
# ===========================================================================

# Update state to reflect execution
out=$(bash "$STORE" update state current_step "1.1 Do the thing")
assert_eq "update current_step returns ok" "ok" "$out"

out=$(bash "$STORE" update state status "in_progress")
assert_eq "update status returns ok" "ok" "$out"

# Verify updates took effect
state_content=$(bash "$STORE" read state)
assert_contains "state shows in_progress" "in_progress" "$state_content"
assert_contains "state shows step 1.1" "1.1 Do the thing" "$state_content"

# ===========================================================================
echo ""
echo "=== Phase 4: Review ==="
# ===========================================================================

# Append a review entry
out=$(bash "$STORE" append reviews "## Review: Step 1.1
- Status: approved
- Agent: kiss-verificator
- Notes: Implementation looks correct")
assert_eq "append review returns ok" "ok" "$out"

# Verify review was written
review_content=$(bash "$STORE" read reviews)
assert_contains "review contains step 1.1" "Step 1.1" "$review_content"
assert_contains "review contains approved" "approved" "$review_content"
assert_contains "review contains kiss-verificator" "kiss-verificator" "$review_content"

# ===========================================================================
echo ""
echo "=== Phase 5: Improve ==="
# ===========================================================================

# Append an insight
out=$(bash "$STORE" append insights "## Insight #1
- Pattern: Tests should validate full lifecycle
- Recommendation: Always test init -> plan -> execute -> review -> improve")
assert_eq "append insight returns ok" "ok" "$out"

# Write token stats
out=$(bash "$STORE" write token-stats "# Token Stats
| Agent | Input | Output | Total |
|-------|-------|--------|-------|
| kiss-executor | 2000 | 500 | 2500 |")
assert_eq "write token-stats returns ok" "ok" "$out"

# Verify insights
insight_content=$(bash "$STORE" read insights)
assert_contains "insights contain pattern" "Tests should validate full lifecycle" "$insight_content"

# Verify token stats
stats_content=$(bash "$STORE" read token-stats)
assert_contains "token-stats contain executor row" "kiss-executor" "$stats_content"

# ===========================================================================
echo ""
echo "=== Phase 6: Checkpoint (session-end) ==="
# ===========================================================================

# Mark status as done before session-end
bash "$STORE" update state status "done" >/dev/null

# Run session-end hook (simulates end of session)
(cd "$TMPDIR_BASE" && bash "$SESSION_END" "$TMPDIR_BASE")

# Verify checkpoint was created
out=$(bash "$STORE" exists checkpoint)
assert_eq "session-end creates CHECKPOINT.md" "true" "$out"

ckpt_content=$(bash "$STORE" read checkpoint)
assert_contains "checkpoint contains CHECKPOINT header" "CHECKPOINT" "$ckpt_content"
assert_contains "checkpoint contains state snapshot" "State snapshot" "$ckpt_content"
assert_contains "checkpoint contains resume instruction" "Resume instruction" "$ckpt_content"

# ===========================================================================
echo ""
echo "=== Phase 7: Guard protection ==="
# ===========================================================================

# Test that guard.sh blocks direct writes to protected files
set +e
CLAUDE_TOOL_NAME=Write CLAUDE_TOOL_INPUT_PATH=".kiss-claw/PLAN.md" \
  bash "$GUARD" >/dev/null 2>&1
guard_block_code=$?
set -e
assert_eq "guard blocks direct Write to PLAN.md" "1" "$guard_block_code"

set +e
CLAUDE_TOOL_NAME=Edit CLAUDE_TOOL_INPUT_PATH=".kiss-claw/STATE.md" \
  bash "$GUARD" >/dev/null 2>&1
guard_block_edit=$?
set -e
assert_eq "guard blocks Edit to STATE.md" "1" "$guard_block_edit"

set +e
CLAUDE_TOOL_NAME=Write CLAUDE_TOOL_INPUT_PATH=".kiss-claw/MEMORY.md" \
  bash "$GUARD" >/dev/null 2>&1
guard_block_mem=$?
set -e
assert_eq "guard blocks Write to MEMORY.md" "1" "$guard_block_mem"

# Test that guard.sh allows store.sh via Bash
set +e
CLAUDE_TOOL_NAME=Bash CLAUDE_TOOL_INPUT_COMMAND="bash scripts/store.sh read plan" \
  bash "$GUARD" >/dev/null 2>&1
guard_allow_code=$?
set -e
assert_eq "guard allows store.sh via Bash" "0" "$guard_allow_code"

# Test that guard allows unrelated tools
set +e
CLAUDE_TOOL_NAME=Read CLAUDE_TOOL_INPUT_PATH="src/main.py" \
  bash "$GUARD" >/dev/null 2>&1
guard_allow_read=$?
set -e
assert_eq "guard allows unrelated Read" "0" "$guard_allow_read"

# ===========================================================================
echo ""
echo "=== RESULTS ==="
echo "  passed: $PASS"
echo "  failed: $FAIL"
echo ""
[[ "$FAIL" -eq 0 ]] && echo "ALL TESTS PASSED" || { echo "SOME TESTS FAILED"; exit 1; }
