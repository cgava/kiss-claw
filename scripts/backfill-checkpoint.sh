#!/bin/bash
set -euo pipefail

# backfill-checkpoint.sh — Temporary transition script
# Appends log entries to the session CHECKPOINT between phases,
# until store.sh supports native upsert by claude_session.

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STORE="$SCRIPT_DIR/store.sh"

usage() {
  cat <<'USAGE'
Usage: backfill-checkpoint.sh --session <id> [options]

Required:
  --session <id>      Session ID (e.g. 20260414-082706)

Options (log entry):
  --agent <name>      Agent name (e.g. kiss-executor)
  --task <desc>       Task description (multi-word, quote it)
  --result <desc>     Result description (multi-word, quote it)
  --task-stdin        Read task from stdin (for multi-line)
  --result-stdin      Read result from stdin (for multi-line)

Options (phase marker):
  --phase <name>      Insert a phase transition comment in the log

Flags:
  --dry-run           Print what would be written, do not modify
  -h, --help          Show this help

Examples:
  # Simple log entry
  backfill-checkpoint.sh --session 20260414-082706 \
    --agent kiss-executor \
    --task "Create backfill-checkpoint.sh" \
    --result "Script created and tested"

  # Phase transition marker
  backfill-checkpoint.sh --session 20260414-082706 \
    --phase "Phase 0 complete"

  # Multi-line task via heredoc
  backfill-checkpoint.sh --session 20260414-082706 \
    --agent kiss-executor \
    --result "Done" \
    --task-stdin <<'EOF'
Create the backfill script with:
- argument parsing
- idempotency checks
- YAML log append
EOF

Notes:
  - Idempotent: duplicate entries (same agent+task+result) are skipped.
  - Timestamps are UTC ISO-8601.
  - This is a temporary script — will be replaced by store.sh upsert.
USAGE
  exit 0
}

# --- Argument parsing ---
SESSION=""
AGENT=""
TASK=""
RESULT=""
PHASE=""
DRY_RUN=false
TASK_FROM_STDIN=false
RESULT_FROM_STDIN=false

while [[ $# -gt 0 ]]; do
  case "$1" in
    --session)    SESSION="${2:?--session requires a value}"; shift 2 ;;
    --agent)      AGENT="${2:?--agent requires a value}"; shift 2 ;;
    --task)       TASK="${2:?--task requires a value}"; shift 2 ;;
    --result)     RESULT="${2:?--result requires a value}"; shift 2 ;;
    --task-stdin) TASK_FROM_STDIN=true; shift ;;
    --result-stdin) RESULT_FROM_STDIN=true; shift ;;
    --phase)      PHASE="${2:?--phase requires a value}"; shift 2 ;;
    --dry-run)    DRY_RUN=true; shift ;;
    -h|--help)    usage ;;
    *)            echo "error: unknown argument: $1" >&2; exit 1 ;;
  esac
done

# --- Validation ---
if [[ -z "$SESSION" ]]; then
  echo "error: --session is required" >&2
  exit 1
fi

# Must provide either --phase or (--agent + --task)
if [[ -z "$PHASE" && -z "$AGENT" ]]; then
  echo "error: provide --phase or --agent (with --task)" >&2
  exit 1
fi

# Read from stdin if requested (only one can use stdin)
if $TASK_FROM_STDIN && $RESULT_FROM_STDIN; then
  echo "error: only one of --task-stdin or --result-stdin can be used (stdin conflict)" >&2
  exit 1
fi

if $TASK_FROM_STDIN; then
  TASK="$(cat)"
fi

if $RESULT_FROM_STDIN; then
  RESULT="$(cat)"
fi

# --- Read current checkpoint ---
export KISS_CLAW_SESSION="$SESSION"
CURRENT="$(bash "$STORE" read checkpoint)"

if [[ -z "$CURRENT" ]]; then
  echo "error: checkpoint is empty or missing for session $SESSION" >&2
  exit 1
fi

# --- Timestamp ---
TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"

# --- Build the new entry ---
# YAML helper: indent a multi-line string as a YAML block scalar (|)
yaml_block() {
  local indent="$1"
  local text="$2"
  local pad=""
  for ((i=0; i<indent; i++)); do pad+="  "; done
  # If single line, emit inline
  if [[ "$(echo "$text" | wc -l)" -le 1 ]]; then
    echo "\"$(printf '%s' "$text" | sed 's/"/\\"/g')\""
  else
    echo "|"
    echo "$text" | while IFS= read -r line; do
      echo "${pad}${line}"
    done
  fi
}

ENTRY=""

if [[ -n "$PHASE" ]]; then
  # Phase transition marker
  ENTRY="  - phase: \"$PHASE\"
    timestamp: \"$TIMESTAMP\""
else
  # Regular log entry
  ENTRY="  - agent: \"$AGENT\"
    timestamp: \"$TIMESTAMP\""

  if [[ -n "$TASK" ]]; then
    TASK_YAML="$(yaml_block 3 "$TASK")"
    ENTRY+="
    task: $TASK_YAML"
  fi

  if [[ -n "$RESULT" ]]; then
    RESULT_YAML="$(yaml_block 3 "$RESULT")"
    ENTRY+="
    result: $RESULT_YAML"
  fi
fi

# --- Idempotency check ---
# Use grep -F (fixed string) to avoid regex escaping issues
is_duplicate() {
  if [[ -n "$PHASE" ]]; then
    echo "$CURRENT" | grep -qF "phase: \"$PHASE\""
  elif [[ -n "$TASK" ]]; then
    # Check both agent and task first line are present in the log
    local first_line
    first_line="$(echo "$TASK" | head -1)"
    echo "$CURRENT" | grep -qF "agent: \"$AGENT\"" \
      && echo "$CURRENT" | grep -qF "$first_line"
  else
    # Agent-only entry — just check agent appears in log section
    return 1
  fi
}

if is_duplicate; then
  echo "skip: duplicate entry detected" >&2
  exit 0
fi

# --- Apply ---
# Replace "log: []" with "log:" + entry, or append entry after existing log entries
if echo "$CURRENT" | grep -q '^log: \[\]'; then
  # Empty log — replace [] with the entry
  NEW_CONTENT="$(echo "$CURRENT" | sed 's/^log: \[\]/log:/')"
  NEW_CONTENT+="
$ENTRY"
else
  # Log already has entries — append at the end
  NEW_CONTENT="$CURRENT
$ENTRY"
fi

if $DRY_RUN; then
  echo "[dry-run] Would write to checkpoint for session $SESSION:"
  echo "---"
  echo "$ENTRY"
  echo "---"
  exit 0
fi

# Write back via store.sh
echo "$NEW_CONTENT" | bash "$STORE" write checkpoint

echo "ok: entry added to checkpoint (session $SESSION)"
