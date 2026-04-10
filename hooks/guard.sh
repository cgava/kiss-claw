#!/bin/bash
# PreToolUse guard — blocks writes to critical files
# Called by Claude Code before any Write/Edit/Bash tool use
# Input: tool name + file path via env vars set by Claude Code hook system

TOOL="${CLAUDE_TOOL_NAME:-}"
FILE="${CLAUDE_TOOL_INPUT_PATH:-}"

# Also catch bash commands that write to protected files
BASH_CMD="${CLAUDE_TOOL_INPUT_COMMAND:-}"

KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"

PROTECTED=(
  "PLAN.md"
  "MEMORY.md"
  "STATE.md"
  "ANALYZED.md"
  "INSIGHTS.md"
  "TOKEN_STATS.md"
  "CHECKPOINT.md"
)

# Normalize: strip leading ./ from path
FILE="${FILE#./}"

check_protected() {
  local target="$1"
  for f in "${PROTECTED[@]}"; do
    if [[ "$target" == "$f" || "$target" == *"/$f" || "$target" == "$KC_DIR/$f" || "$target" == *"/$KC_DIR/$f" ]]; then
      echo "BLOCK: $KC_DIR/$f is a protected file. Only its owning agent may write to it."
      echo "  Owning agents: PLAN.md→kiss-orchestrator, MEMORY.md→kiss-improver, STATE.md→kiss-orchestrator, ANALYZED.md+INSIGHTS.md→kiss-improver"
      exit 1
    fi
  done
}

# Check direct file writes
if [[ "$TOOL" == "Write" || "$TOOL" == "Edit" || "$TOOL" == "str_replace_based_edit_tool" ]]; then
  check_protected "$FILE"
fi

# Check bash commands that redirect into protected files
if [[ "$TOOL" == "Bash" && -n "$BASH_CMD" ]]; then
  # Allow store.sh — it is the authorized persistence path for /kiss-store.
  # Agents call scripts/store.sh via Bash to read/write protected files safely.
  if [[ "$BASH_CMD" == *scripts/store.sh* ]]; then
    exit 0
  fi
  for f in "${PROTECTED[@]}"; do
    if echo "$BASH_CMD" | grep -qE "(>|>>)\s*\.?/?(${KC_DIR}/)?${f}(\s|$)"; then
      echo "BLOCK: bash command attempts to write to protected file $KC_DIR/$f."
      exit 1
    fi
  done
fi

exit 0
