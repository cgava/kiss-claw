#!/bin/bash
# PreToolUse guard — blocks writes to critical files
# Called by Claude Code before any Write/Edit/Bash tool use
# Input: tool name + file path via env vars set by Claude Code hook system

TOOL="${CLAUDE_TOOL_NAME:-}"
FILE="${CLAUDE_TOOL_INPUT_PATH:-}"

# Also catch bash commands that write to protected files
BASH_CMD="${CLAUDE_TOOL_INPUT_COMMAND:-}"

KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
AGENTS_DIR="${KISS_CLAW_AGENTS_DIR:-$KC_DIR/agents}"
PROJECT_DIR="${KISS_CLAW_PROJECT_DIR:-$KC_DIR/project}"
SESSIONS_DIR="${KISS_CLAW_SESSIONS_DIR:-$KC_DIR/sessions}"

# Protected files grouped by location and owner
# agents/ : MEMORY_kiss-*.md → own agent, INSIGHTS.md → kiss-improver, ANALYZED.md → kiss-improver
# project/ : MEMORY.md → kiss-improver
# sessions/*/ : PLAN.md → kiss-orchestrator, STATE.md → kiss-orchestrator, CHECKPOINT.md → kiss-orchestrator

# Normalize: strip leading ./ from path
FILE="${FILE#./}"

check_protected() {
  local target="$1"

  # --- agents/ files ---
  # MEMORY_kiss-*.md (agent-scoped memory files)
  if [[ "$target" == */MEMORY_kiss-*.md || "$target" == MEMORY_kiss-*.md ]]; then
    if [[ "$target" == *"$AGENTS_DIR/"* || "$target" == "$AGENTS_DIR/"* ]]; then
      echo "BLOCK: $target is a protected agent memory file. Only the owning agent may write to it via /kiss-store."
      echo "  Each MEMORY_kiss-<agent>.md is owned by kiss-<agent>."
      exit 1
    fi
  fi

  # INSIGHTS.md
  if [[ "$target" == "INSIGHTS.md" || "$target" == *"/INSIGHTS.md" ]]; then
    if [[ "$target" == *"$AGENTS_DIR/"* || "$target" == "$AGENTS_DIR/"* || "$target" == "INSIGHTS.md" ]]; then
      echo "BLOCK: $target is a protected file. Only kiss-improver may write to it via /kiss-store."
      exit 1
    fi
  fi

  # ANALYZED.md
  if [[ "$target" == "ANALYZED.md" || "$target" == *"/ANALYZED.md" ]]; then
    if [[ "$target" == *"$AGENTS_DIR/"* || "$target" == "$AGENTS_DIR/"* || "$target" == "ANALYZED.md" ]]; then
      echo "BLOCK: $target is a protected file. Only kiss-improver may write to it via /kiss-store."
      exit 1
    fi
  fi

  # --- project/ files ---
  # MEMORY.md
  if [[ "$target" == "MEMORY.md" || "$target" == *"/MEMORY.md" ]]; then
    if [[ "$target" == *"$PROJECT_DIR/"* || "$target" == "$PROJECT_DIR/"* || "$target" == "MEMORY.md" ]]; then
      echo "BLOCK: $target is a protected file. Only kiss-improver may write to it via /kiss-store."
      exit 1
    fi
  fi

  # --- sessions/*/ files ---
  # PLAN.md, STATE.md, CHECKPOINT.md in any session directory
  for f in PLAN.md STATE.md CHECKPOINT.md; do
    if [[ "$target" == "$f" || "$target" == *"/$f" ]]; then
      # Check if path is inside sessions dir (any session subdirectory)
      if [[ "$target" == *"$SESSIONS_DIR/"*"/$f" || "$target" == "$SESSIONS_DIR/"*"/$f" || "$target" == "$f" ]]; then
        echo "BLOCK: $target is a protected session file. Only kiss-orchestrator may write to it via /kiss-store."
        echo "  Owners: PLAN.md → kiss-orchestrator, STATE.md → kiss-orchestrator, CHECKPOINT.md → kiss-orchestrator"
        exit 1
      fi
    fi
  done
}

check_bash_protected() {
  local cmd="$1"

  # Agent-scoped files
  for f in INSIGHTS.md ANALYZED.md; do
    if echo "$cmd" | grep -qE "(>|>>)\s*[^ ]*${f}(\s|$)"; then
      echo "BLOCK: bash command attempts to write to protected file $f."
      exit 1
    fi
  done
  # MEMORY_kiss-*.md
  if echo "$cmd" | grep -qE "(>|>>)\s*[^ ]*MEMORY_kiss-[^ ]*\.md(\s|$)"; then
    echo "BLOCK: bash command attempts to write to protected agent memory file."
    exit 1
  fi

  # Project-scoped files
  if echo "$cmd" | grep -qE "(>|>>)\s*[^ ]*MEMORY\.md(\s|$)"; then
    echo "BLOCK: bash command attempts to write to protected file MEMORY.md."
    exit 1
  fi

  # Session-scoped files
  for f in PLAN.md STATE.md CHECKPOINT.md; do
    if echo "$cmd" | grep -qE "(>|>>)\s*[^ ]*${f}(\s|$)"; then
      echo "BLOCK: bash command attempts to write to protected session file $f."
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
  check_bash_protected "$BASH_CMD"
fi

exit 0
