#!/bin/bash
# PreToolUse guard — blocks writes to critical files
# Called by Claude Code before any Write/Edit/Bash tool use
# Input: tool name + file path via env vars set by Claude Code hook system

TOOL="${CLAUDE_TOOL_NAME:-}"
FILE="${CLAUDE_TOOL_INPUT_PATH:-}"

# Also catch bash commands that write to protected files
BASH_CMD="${CLAUDE_TOOL_INPUT_COMMAND:-}"

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
    if [[ "$target" == "$f" || "$target" == *"/$f" ]]; then
      echo "BLOCK: $f is a protected file. Only its owning agent may write to it."
      echo "  Owning agents: PLAN.md→orchestrator, MEMORY.md→analyzer, STATE.md→orchestrator, ANALYZED.md+INSIGHTS.md→analyzer"
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
  for f in "${PROTECTED[@]}"; do
    if echo "$BASH_CMD" | grep -qE "(>|>>)\s*\.?/?${f}(\s|$)"; then
      echo "BLOCK: bash command attempts to write to protected file $f."
      exit 1
    fi
  done
fi

exit 0
