#!/bin/bash
# Writes CHECKPOINT.md before a /compact or manual trigger
# Usage: called by the SessionEnd hook or manually via /compact

PROJECT_DIR="${1:-.}"
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
DATE=$(date +%Y-%m-%d)
TIME=$(date +%H:%M)

mkdir -p "$PROJECT_DIR/$KC_DIR"

STATE_FILE="$PROJECT_DIR/$KC_DIR/STATE.md"
PLAN_FILE="$PROJECT_DIR/$KC_DIR/PLAN.md"
OUT="$PROJECT_DIR/$KC_DIR/CHECKPOINT.md"

echo "# CHECKPOINT — $DATE $TIME" > "$OUT"
echo "" >> "$OUT"

# Snapshot current step from STATE.md
if [[ -f "$STATE_FILE" ]]; then
  echo "## State snapshot" >> "$OUT"
  grep -E "(current_phase|current_step|status|blocker|updated)" "$STATE_FILE" >> "$OUT"
  echo "" >> "$OUT"

  echo "## Completed steps (last 10)" >> "$OUT"
  grep -A 20 "^completed:" "$STATE_FILE" | head -12 >> "$OUT"
  echo "" >> "$OUT"
fi

# Files touched this session (git if available, else recent mtime)
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

echo "CHECKPOINT written to $OUT"
