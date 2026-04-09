#!/bin/bash
# kiss-claw project initializer
# Run from your project root to set up .kiss-claw/ with templates.
#
# Usage:
#   kiss-claw-init              # creates .kiss-claw/ with templates
#   kiss-claw-init --status     # shows what's already initialized

set -euo pipefail

# Resolve repo root (one level up from scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$REPO_DIR/templates"

KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"

show_status() {
  echo "kiss-claw project status"
  echo "========================"
  echo "Output dir: $KC_DIR"
  echo ""

  if [ ! -d "$KC_DIR" ]; then
    echo "Not initialized. Run: $(basename "$0")"
    return
  fi

  for f in MEMORY.md MEMORY_kiss-orchestrator.md MEMORY_kiss-executor.md MEMORY_kiss-verificator.md MEMORY_kiss-improver.md; do
    if [ -f "$KC_DIR/$f" ]; then
      echo "  ✓ $f"
    else
      echo "  ✗ $f (missing)"
    fi
  done

  for f in PLAN.md STATE.md CHECKPOINT.md INSIGHTS.md ANALYZED.md TOKEN_STATS.md REVIEWS.md SCRATCH.md; do
    if [ -f "$KC_DIR/$f" ]; then
      echo "  ● $f (runtime)"
    fi
  done
}

do_init() {
  if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: templates directory not found at $TEMPLATE_DIR"
    echo "  Is kiss-claw installed correctly?"
    exit 1
  fi

  echo "Initializing kiss-claw in $(pwd)/$KC_DIR ..."
  mkdir -p "$KC_DIR"

  # Copy MEMORY.md template
  if [ -f "$KC_DIR/MEMORY.md" ]; then
    echo "  skip MEMORY.md (already exists)"
  else
    cp "$TEMPLATE_DIR/MEMORY.md.template" "$KC_DIR/MEMORY.md"
    echo "  created MEMORY.md"
  fi

  # Split agent memory templates into individual files
  if [ -f "$TEMPLATE_DIR/MEMORY_agents.md.template" ]; then
    for agent in kiss-orchestrator kiss-executor kiss-verificator kiss-improver; do
      target="$KC_DIR/MEMORY_${agent}.md"
      if [ -f "$target" ]; then
        echo "  skip MEMORY_${agent}.md (already exists)"
      else
        # Extract the section for this agent from the combined template
        sed -n "/^# MEMORY_${agent}.md/,/^---$/p" "$TEMPLATE_DIR/MEMORY_agents.md.template" \
          | sed '$ { /^---$/d }' \
          > "$target"
        echo "  created MEMORY_${agent}.md"
      fi
    done
  fi

  # Add .kiss-claw to .gitignore if not already there
  if [ -f .gitignore ]; then
    if ! grep -q "^${KC_DIR}$" .gitignore 2>/dev/null; then
      echo "$KC_DIR" >> .gitignore
      echo "  added $KC_DIR to .gitignore"
    fi
  else
    echo "$KC_DIR" > .gitignore
    echo "  created .gitignore with $KC_DIR"
  fi

  echo ""
  echo "Done. Next steps:"
  echo "  1. Edit $KC_DIR/MEMORY.md with your project info"
  echo "  2. Start a Claude Code session — the SessionStart hook will show the agent menu"
}

# --- main ---

case "${1:-}" in
  --status)
    show_status
    ;;
  --help|-h)
    echo "Usage: $(basename "$0") [--status|--help]"
    echo "  Run from your project root to initialize kiss-claw."
    ;;
  "")
    do_init
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
esac
