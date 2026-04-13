#!/bin/bash
# tests/test-mock-store.sh — proves store.sh can be replaced by a custom implementation
# Creates a mock store.sh that uses a single JSON-like flat file instead of
# separate markdown files, then runs the same interface operations against it.
set -uo pipefail

PASS=0
FAIL=0

TMPDIR_BASE=$(mktemp -d)
MOCK_DIR="$TMPDIR_BASE/mock-bin"
MOCK_DB="$TMPDIR_BASE/mock-db.txt"
export KISS_CLAW_DIR="$TMPDIR_BASE/.kiss-claw"
export KISS_CLAW_SESSION="mock-session-01"
mkdir -p "$MOCK_DIR" "$KISS_CLAW_DIR"

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

# ---------------------------------------------------------------------------
# Build the mock store.sh
# ---------------------------------------------------------------------------
# This mock stores ALL data in a single flat file ($MOCK_DB) using a simple
# line-based format:   RESOURCE<TAB>CONTENT
# No separate .md files, no subdirectories — completely different internals,
# same external interface.
# ---------------------------------------------------------------------------
cat > "$MOCK_DIR/store.sh" <<'MOCKEOF'
#!/bin/bash
set -euo pipefail

ACTION="${1:?usage: store.sh <action> <resource> [content...]}"
RESOURCE="${2:-}"
DB="${MOCK_STORE_DB:?MOCK_STORE_DB must be set}"

# Known resources (validation only — no file-path mapping needed)
# Session-scoped resources require KISS_CLAW_SESSION
is_session_resource() {
  case "$1" in
    plan|state|scratch|reviews|checkpoint) return 0 ;;
    *) return 1 ;;
  esac
}

is_known() {
  case "$1" in
    plan|state|scratch|memory|memory:kiss-*|reviews|insights|analyzed|checkpoint|sessions) return 0 ;;
    *) return 1 ;;
  esac
}

require_session() {
  if is_session_resource "$1" && [[ -z "${KISS_CLAW_SESSION:-}" ]]; then
    echo "error: KISS_CLAW_SESSION is required for resource '$1' (session-scoped)" >&2
    exit 1
  fi
}

case "$ACTION" in
  read)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh read <resource>" >&2; exit 1; }
    is_known "$RESOURCE" || { echo "unknown resource: $RESOURCE" >&2; exit 1; }
    require_session "$RESOURCE"
    [[ -f "$DB" ]] || exit 0
    # Extract all lines for this resource and reconstruct content
    while IFS=$'\t' read -r key value; do
      [[ "$key" == "$RESOURCE" ]] && printf '%s\n' "$value"
    done < "$DB"
    ;;

  write)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh write <resource> [content...]" >&2; exit 1; }
    is_known "$RESOURCE" || { echo "unknown resource: $RESOURCE" >&2; exit 1; }
    require_session "$RESOURCE"
    shift 2
    CONTENT="$*"
    # Remove old entries for this resource
    if [[ -f "$DB" ]]; then
      grep -v "^${RESOURCE}	" "$DB" > "$DB.tmp" 2>/dev/null || true
      mv "$DB.tmp" "$DB"
    fi
    # Write new content (one DB line per content line)
    if [[ -n "$CONTENT" ]]; then
      while IFS= read -r line; do
        printf '%s\t%s\n' "$RESOURCE" "$line" >> "$DB"
      done <<< "$CONTENT"
    else
      while IFS= read -r line; do
        printf '%s\t%s\n' "$RESOURCE" "$line" >> "$DB"
      done
    fi
    echo "ok"
    ;;

  append)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh append <resource> [content...]" >&2; exit 1; }
    is_known "$RESOURCE" || { echo "unknown resource: $RESOURCE" >&2; exit 1; }
    require_session "$RESOURCE"
    shift 2
    CONTENT="$*"
    if [[ -n "$CONTENT" ]]; then
      while IFS= read -r line; do
        printf '%s\t%s\n' "$RESOURCE" "$line" >> "$DB"
      done <<< "$CONTENT"
    else
      while IFS= read -r line; do
        printf '%s\t%s\n' "$RESOURCE" "$line" >> "$DB"
      done
    fi
    echo "ok"
    ;;

  update)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh update <resource> <field> <value...>" >&2; exit 1; }
    is_known "$RESOURCE" || { echo "unknown resource: $RESOURCE" >&2; exit 1; }
    require_session "$RESOURCE"
    FIELD="${3:?usage: store.sh update <resource> <field> <value...>}"
    # Check resource exists in DB
    if [[ ! -f "$DB" ]] || ! grep -q "^${RESOURCE}	" "$DB" 2>/dev/null; then
      echo "resource not found: $RESOURCE" >&2
      exit 1
    fi
    shift 3
    VALUE="$*"
    # Replace the line containing the field
    local_tmp="$DB.tmp"
    matched=0
    while IFS=$'\t' read -r key content; do
      if [[ "$key" == "$RESOURCE" && "$content" == "${FIELD}:"* ]]; then
        printf '%s\t%s: "%s"\n' "$key" "$FIELD" "$VALUE" >> "$local_tmp"
        matched=1
      else
        printf '%s\t%s\n' "$key" "$content" >> "$local_tmp"
      fi
    done < "$DB"
    mv "$local_tmp" "$DB"
    echo "ok"
    ;;

  exists)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh exists <resource>" >&2; exit 1; }
    is_known "$RESOURCE" || { echo "unknown resource: $RESOURCE" >&2; exit 1; }
    require_session "$RESOURCE"
    if [[ -f "$DB" ]] && grep -q "^${RESOURCE}	" "$DB" 2>/dev/null; then
      echo "true"
    else
      echo "false"
    fi
    ;;

  list)
    [[ -f "$DB" ]] || exit 0
    cut -f1 "$DB" | sort -u
    ;;

  *)
    echo "unknown action: $ACTION" >&2
    exit 1
    ;;
esac
MOCKEOF
chmod +x "$MOCK_DIR/store.sh"

# ---------------------------------------------------------------------------
# Point STORE at the mock and set mock env
# ---------------------------------------------------------------------------
STORE="$MOCK_DIR/store.sh"
export MOCK_STORE_DB="$MOCK_DB"

echo "=== Mock store replacement test ==="
echo "Mock: single flat-file DB at $MOCK_DB"
echo ""

# ---------------------------------------------------------------------------
echo "--- write + read ---"

out=$(bash "$STORE" write plan "# My Plan")
assert_eq "mock write returns ok" "ok" "$out"

out=$(bash "$STORE" read plan)
assert_eq "mock read returns written content" "# My Plan" "$out"

# Overwrite
bash "$STORE" write plan "# Updated Plan" >/dev/null
out=$(bash "$STORE" read plan)
assert_eq "mock write overwrites previous" "# Updated Plan" "$out"

# ---------------------------------------------------------------------------
echo "--- append ---"

bash "$STORE" write scratch "line1" >/dev/null
out=$(bash "$STORE" append scratch "line2")
assert_eq "mock append returns ok" "ok" "$out"

out=$(bash "$STORE" read scratch)
expected=$(printf 'line1\nline2')
assert_eq "mock append adds content" "$expected" "$out"

# ---------------------------------------------------------------------------
echo "--- exists ---"

out=$(bash "$STORE" exists plan)
assert_eq "mock exists returns true for written resource" "true" "$out"

out=$(bash "$STORE" exists checkpoint)
assert_eq "mock exists returns false for missing resource" "false" "$out"

# ---------------------------------------------------------------------------
echo "--- update ---"

bash "$STORE" write state "$(printf 'status: "idle"\ncurrent_step: "1.0"')" >/dev/null

out=$(bash "$STORE" update state status running)
assert_eq "mock update returns ok" "ok" "$out"

out=$(bash "$STORE" read state)
assert_contains "mock update changed field" 'status: "running"' "$out"
assert_contains "mock update preserved other field" 'current_step: "1.0"' "$out"

# update on missing resource should fail
set +e
err=$(bash "$STORE" update insights field value 2>&1)
code=$?
set -e
assert_eq "mock update missing resource exits 1" "1" "$code"
assert_contains "mock update missing resource error" "resource not found" "$err"

# ---------------------------------------------------------------------------
echo "--- list ---"

out=$(bash "$STORE" list)
assert_contains "mock list includes plan" "plan" "$out"
assert_contains "mock list includes state" "state" "$out"
assert_contains "mock list includes scratch" "scratch" "$out"

# ---------------------------------------------------------------------------
echo "--- interface parity: unknown resource rejected ---"

set +e
err=$(bash "$STORE" read "bogus" 2>&1)
code=$?
set -e
assert_eq "mock rejects unknown resource" "1" "$code"

# ---------------------------------------------------------------------------
echo "--- interface parity: memory:kiss-* sub-resources ---"

bash "$STORE" write "memory:kiss-orchestrator" "agent notes" >/dev/null
out=$(bash "$STORE" read "memory:kiss-orchestrator")
assert_eq "mock supports memory:kiss-* resources" "agent notes" "$out"

out=$(bash "$STORE" list)
assert_contains "mock list includes memory:kiss-orchestrator" "memory:kiss-orchestrator" "$out"

# ---------------------------------------------------------------------------
echo "--- session requirement ---"

# Session-scoped resources must fail without KISS_CLAW_SESSION
for res in plan state reviews scratch checkpoint; do
  set +e
  err=$(env -u KISS_CLAW_SESSION bash "$STORE" read "$res" 2>&1)
  code=$?
  set -e
  assert_eq "mock $res without session exits 1" "1" "$code"
  assert_contains "mock $res error mentions KISS_CLAW_SESSION" "KISS_CLAW_SESSION" "$err"
done

# Non-session resources should work without KISS_CLAW_SESSION
for res in memory insights analyzed; do
  set +e
  env -u KISS_CLAW_SESSION bash "$STORE" exists "$res" >/dev/null 2>&1
  code=$?
  set -e
  assert_eq "mock $res without session succeeds" "0" "$code"
done

# ---------------------------------------------------------------------------
echo ""
echo "=== RESULTS ==="
echo "  passed: $PASS"
echo "  failed: $FAIL"
echo ""
if [[ "$FAIL" -eq 0 ]]; then
  echo "ALL TESTS PASSED — store.sh interface is replaceable"
else
  echo "SOME TESTS FAILED"
  exit 1
fi
