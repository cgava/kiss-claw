#!/bin/bash
# SessionEnd hook — runs as a command (prompt hooks unsupported outside REPL)
# Handles: checkpoint, STATE.md log entry, agent file cleanup

PROJECT_DIR="${1:-.}"
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
AGENT_FILE="$PROJECT_DIR/.poc-session-agent"
STATE_FILE="$PROJECT_DIR/$KC_DIR/STATE.md"
OUT="$PROJECT_DIR/$KC_DIR/CHECKPOINT.md"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

# --- 1. Write CHECKPOINT.md ---
mkdir -p "$PROJECT_DIR/$KC_DIR"

echo "# CHECKPOINT — $DATE $TIME" > "$OUT"
echo "" >> "$OUT"

if [[ -f "$STATE_FILE" ]]; then
  echo "## State snapshot" >> "$OUT"
  grep -E "(current_phase|current_step|status|blocker|updated)" "$STATE_FILE" >> "$OUT"
  echo "" >> "$OUT"

  echo "## Completed steps (last 10)" >> "$OUT"
  grep -A 20 "^completed:" "$STATE_FILE" | head -12 >> "$OUT"
  echo "" >> "$OUT"
fi

echo "## Files modified this session" >> "$OUT"
if git -C "$PROJECT_DIR" rev-parse --is-inside-work-tree &>/dev/null; then
  git -C "$PROJECT_DIR" diff --name-only HEAD 2>/dev/null >> "$OUT"
  git -C "$PROJECT_DIR" ls-files --others --exclude-standard 2>/dev/null >> "$OUT"
else
  find "$PROJECT_DIR" -maxdepth 3 -newer "$STATE_FILE" -not -path "*/.git/*" \
    -not -name "CHECKPOINT.md" -not -name ".poc-session-agent" 2>/dev/null >> "$OUT"
fi
echo "" >> "$OUT"

echo "## Resume instruction" >> "$OUT"
echo "Read this file first, then STATE.md, then MEMORY.md. Do not re-read PLAN.md unless" >> "$OUT"
echo "the current step is ambiguous. Proceed from current_step." >> "$OUT"

# --- 2. Read active agent (if any) ---
AGENT=""
if [[ -f "$AGENT_FILE" ]]; then
  AGENT=$(cat "$AGENT_FILE" | tr -d '[:space:]')
fi

# --- 3. If agent was kiss-orchestrator, update STATE.md ---
if [[ "$AGENT" == "kiss-orchestrator" && -f "$STATE_FILE" ]]; then
  if grep -q "^updated:" "$STATE_FILE"; then
    sed -i "s/^updated:.*$/updated: $DATE/" "$STATE_FILE"
  else
    echo "updated: $DATE" >> "$STATE_FILE"
  fi

  STEP=$(grep -m1 "^current_step:" "$STATE_FILE" | sed 's/^current_step:[[:space:]]*//')
  STATUS=$(grep -m1 "^status:" "$STATE_FILE" | sed 's/^status:[[:space:]]*//')
  LOG_ENTRY="- $DATE: session ended — step: ${STEP:-unknown}, status: ${STATUS:-unknown}"

  if grep -q "^log:" "$STATE_FILE"; then
    sed -i "/^log:/a\\$LOG_ENTRY" "$STATE_FILE"
  else
    printf "\nlog:\n%s\n" "$LOG_ENTRY" >> "$STATE_FILE"
  fi
fi

# --- 4. Delete agent file ---
rm -f "$AGENT_FILE"

# --- 5. Print nothing (exit silently) ---
