#!/bin/bash
# SessionEnd hook — runs as a command (prompt hooks unsupported outside REPL)
# Handles: checkpoint, STATE.md log entry, agent file cleanup

PROJECT_DIR="${1:-.}"
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
STORE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)/scripts/store.sh"
export KISS_CLAW_DIR="$KC_DIR"

AGENT_FILE="$PROJECT_DIR/.poc-session-agent"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

# --- 1. Write CHECKPOINT.md via store.sh ---
CKPT="# CHECKPOINT — $DATE $TIME"
CKPT="$CKPT
"

STATE_CONTENT=$("$STORE" read state)
if [[ -n "$STATE_CONTENT" ]]; then
  CKPT="$CKPT
## State snapshot"
  CKPT="$CKPT
$(echo "$STATE_CONTENT" | grep -E "(current_phase|current_step|status|blocker|updated)")"
  CKPT="$CKPT
"

  CKPT="$CKPT
## Completed steps (last 10)"
  CKPT="$CKPT
$(echo "$STATE_CONTENT" | grep -A 20 "^completed:" | head -12)"
  CKPT="$CKPT
"
fi

CKPT="$CKPT
## Files modified this session"
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  CKPT="$CKPT
$(git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null)
$(git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null)"
else
  STATE_FILE="$PROJECT_DIR/$KC_DIR/STATE.md"
  CKPT="$CKPT
$(find "$PROJECT_DIR" -maxdepth 3 -newer "$STATE_FILE" -not -path "*/.git/*" \
    -not -name "CHECKPOINT.md" -not -name ".poc-session-agent" 2>/dev/null)"
fi
CKPT="$CKPT
"

CKPT="$CKPT
## Resume instruction
Read this file first, then STATE.md, then MEMORY.md. Do not re-read PLAN.md unless
the current step is ambiguous. Proceed from current_step."

echo "$CKPT" | "$STORE" write checkpoint

# --- 2. Read active agent (if any) ---
AGENT=""
if [[ -f "$AGENT_FILE" ]]; then
  AGENT=$(cat "$AGENT_FILE" | tr -d '[:space:]')
fi

# --- 3. If agent was kiss-orchestrator, update STATE.md ---
if [[ "$AGENT" == "kiss-orchestrator" && -n "$STATE_CONTENT" ]]; then
  "$STORE" update state updated "$DATE"

  STEP=$(echo "$STATE_CONTENT" | grep -m1 "^current_step:" | sed 's/^current_step:[[:space:]]*//' | tr -d '"')
  STATUS=$(echo "$STATE_CONTENT" | grep -m1 "^status:" | sed 's/^status:[[:space:]]*//' | tr -d '"')
  LOG_ENTRY="  - \"$DATE: session ended — step: ${STEP:-unknown}, status: ${STATUS:-unknown}\""

  "$STORE" append state "$LOG_ENTRY"
fi

# --- 4. Delete agent file ---
rm -f "$AGENT_FILE"

# --- 5. Print nothing (exit silently) ---
