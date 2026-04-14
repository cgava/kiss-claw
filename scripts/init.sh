#!/bin/bash
# kiss-claw project initializer
# Run from your project root to set up .kiss-claw/ with templates.
#
# Usage:
#   kiss-claw-init              # creates .kiss-claw/ with templates (interactive if tty)
#   kiss-claw-init --status     # shows what's already initialized
#   kiss-claw-init --migrate    # migrates v7 (flat) layout to v8 (sub-directories)

set -euo pipefail

# Resolve repo root (one level up from scripts/)
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEMPLATE_DIR="$REPO_DIR/templates"
STORE="$REPO_DIR/scripts/store.sh"

KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
export KISS_CLAW_DIR="$KC_DIR"

# Defaults for sub-directories
DEFAULT_AGENTS_DIR="$KC_DIR/agents"
DEFAULT_PROJECT_DIR="$KC_DIR/project"
DEFAULT_SESSIONS_DIR="$KC_DIR/sessions"

# Interactive prompt for a sub-directory path.
# Usage: ask_subdir_path <label> <default_path> [<source_symlink>]
# Sets REPLY_PATH to the chosen path and REPLY_SYMLINK to the symlink target (or empty).
# When <source_symlink> is provided, a symlink to that path is proposed as the default choice.
ask_subdir_path() {
  local label="$1"
  local default_path="$2"
  local source_symlink="${3:-}"

  REPLY_PATH="$default_path"
  REPLY_SYMLINK=""

  # Non-interactive: use defaults silently
  if [[ ! -t 0 ]]; then
    return
  fi

  echo ""
  echo "$label :"

  if [[ -n "$source_symlink" ]]; then
    echo "  1 - Symlink vers $source_symlink (defaut)"
    echo "  2 - $default_path (local)"
    echo "  3 - Autre chemin"
    echo "  4 - Symlink vers un dossier existant"
    read -rp "Choix [1] : " choice
    choice="${choice:-1}"

    case "$choice" in
      1)
        REPLY_PATH="$default_path"
        REPLY_SYMLINK="$source_symlink"
        ;;
      2)
        REPLY_PATH="$default_path"
        ;;
      3)
        read -rp "Chemin : " custom_path
        if [[ -z "$custom_path" ]]; then
          echo "  (vide, utilisation du defaut)"
          REPLY_SYMLINK="$source_symlink"
        else
          REPLY_PATH="$custom_path"
        fi
        ;;
      4)
        read -rp "Chemin cible du symlink : " symlink_target
        if [[ -z "$symlink_target" ]]; then
          echo "  (vide, utilisation du defaut)"
          REPLY_SYMLINK="$source_symlink"
        else
          REPLY_PATH="$default_path"
          REPLY_SYMLINK="$symlink_target"
        fi
        ;;
      *)
        echo "  Choix invalide, utilisation du defaut"
        REPLY_SYMLINK="$source_symlink"
        ;;
    esac
  else
    echo "  1 - $default_path (defaut)"
    echo "  2 - Autre chemin"
    echo "  3 - Symlink vers un dossier existant"
    read -rp "Choix [1] : " choice
    choice="${choice:-1}"

    case "$choice" in
      1)
        REPLY_PATH="$default_path"
        ;;
      2)
        read -rp "Chemin : " custom_path
        if [[ -z "$custom_path" ]]; then
          echo "  (vide, utilisation du defaut)"
          REPLY_PATH="$default_path"
        else
          REPLY_PATH="$custom_path"
        fi
        ;;
      3)
        read -rp "Chemin cible du symlink : " symlink_target
        if [[ -z "$symlink_target" ]]; then
          echo "  (vide, utilisation du defaut sans symlink)"
          REPLY_PATH="$default_path"
        else
          REPLY_PATH="$default_path"
          REPLY_SYMLINK="$symlink_target"
        fi
        ;;
      *)
        echo "  Choix invalide, utilisation du defaut"
        REPLY_PATH="$default_path"
        ;;
    esac
  fi
}

# Create a directory or symlink based on ask_subdir_path results.
# Usage: create_subdir <path> <symlink_target>
create_subdir() {
  local dir_path="$1"
  local symlink_target="$2"

  if [[ -n "$symlink_target" ]]; then
    if [[ ! -d "$symlink_target" ]]; then
      echo "  Error: symlink target '$symlink_target' does not exist or is not a directory"
      exit 1
    fi
    # Ensure parent exists
    mkdir -p "$(dirname "$dir_path")"
    # Refuse to replace a real directory — rm -rf on re-init would be destructive
    if [[ -d "$dir_path" && ! -L "$dir_path" ]]; then
      echo "  Error: '$dir_path' is a real directory (not a symlink). Remove it manually before re-initializing as a symlink."
      exit 1
    fi
    # Remove existing symlink if present before creating new one
    if [[ -L "$dir_path" ]]; then
      rm "$dir_path"
    fi
    ln -s "$symlink_target" "$dir_path"
    echo "  symlink $dir_path -> $symlink_target"
  else
    mkdir -p "$dir_path"
    echo "  created $dir_path"
  fi
}

show_status() {
  echo "kiss-claw project status"
  echo "========================"
  echo "Root dir : $KC_DIR"
  echo ""

  if [ ! -d "$KC_DIR" ]; then
    echo "Not initialized. Run: $(basename "$0")"
    return
  fi

  # Resolve sub-directory paths (respect env overrides)
  local agents_dir="${KISS_CLAW_AGENTS_DIR:-$DEFAULT_AGENTS_DIR}"
  local project_dir="${KISS_CLAW_PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
  local sessions_dir="${KISS_CLAW_SESSIONS_DIR:-$DEFAULT_SESSIONS_DIR}"

  echo "Sub-directories:"
  for dir_info in "agents:$agents_dir" "project:$project_dir" "sessions:$sessions_dir"; do
    local label="${dir_info%%:*}"
    local path="${dir_info#*:}"
    if [[ -L "$path" ]]; then
      local target
      target=$(readlink "$path")
      echo "  $label: $path -> $target (symlink)"
    elif [[ -d "$path" ]]; then
      echo "  $label: $path"
    else
      echo "  $label: $path (missing)"
    fi
  done
  echo ""

  # Export for store.sh
  export KISS_CLAW_AGENTS_DIR="$agents_dir"
  export KISS_CLAW_PROJECT_DIR="$project_dir"
  export KISS_CLAW_SESSIONS_DIR="$sessions_dir"

  echo "Project resources:"
  for res in memory sessions; do
    case "$res" in
      memory)   label="MEMORY.md" ;;
      sessions) label="SESSIONS.json" ;;
    esac
    if [ "$("$STORE" exists "$res")" = "true" ]; then
      echo "  ✓ $label"
    else
      echo "  ✗ $label (missing)"
    fi
  done

  echo ""
  echo "Agent resources:"
  for res in memory:kiss-orchestrator memory:kiss-executor memory:kiss-verificator memory:kiss-improver; do
    label="MEMORY_${res#memory:}.md"
    if [ "$("$STORE" exists "$res")" = "true" ]; then
      echo "  ✓ $label"
    else
      echo "  ✗ $label (missing)"
    fi
  done
  for res in insights analyzed; do
    label="$(echo "$res" | tr '[:lower:]' '[:upper:]').md"
    if [ "$("$STORE" exists "$res")" = "true" ]; then
      echo "  ● $label (runtime)"
    fi
  done

  echo ""
  echo "Session resources:"
  if [[ -d "$sessions_dir" ]]; then
    local found_session=false
    for session_dir in "$sessions_dir"/*/; do
      [[ -d "$session_dir" ]] || continue
      found_session=true
      local session_name
      session_name=$(basename "$session_dir")
      echo "  Session: $session_name"
      export KISS_CLAW_SESSION="$session_name"
      for res in plan state reviews scratch checkpoint; do
        case "$res" in
          *)  label="$(echo "$res" | tr '[:lower:]' '[:upper:]').md" ;;
        esac
        if [ "$("$STORE" exists "$res")" = "true" ]; then
          echo "    ● $label"
        fi
      done
    done
    if [[ "$found_session" = false ]]; then
      echo "  (no sessions yet)"
    fi
  else
    echo "  (sessions directory missing)"
  fi
}

do_init() {
  if [ ! -d "$TEMPLATE_DIR" ]; then
    echo "Error: templates directory not found at $TEMPLATE_DIR"
    echo "  Is kiss-claw installed correctly?"
    exit 1
  fi

  echo "Initializing kiss-claw in $(pwd)/$KC_DIR ..."

  # --- 2.1 Interactive dialogue for each sub-directory ---
  local source_agents_dir="$REPO_DIR/.kiss-claw/agents"

  ask_subdir_path "Chemin du dossier de persistance des agents (prompts additionnels)" "$DEFAULT_AGENTS_DIR" "$source_agents_dir"
  local agents_path="$REPLY_PATH"
  local agents_symlink="$REPLY_SYMLINK"

  ask_subdir_path "Chemin de persistance des donnees projects" "$DEFAULT_PROJECT_DIR"
  local project_path="$REPLY_PATH"
  local project_symlink="$REPLY_SYMLINK"

  ask_subdir_path "Chemin de persistance des donnees de sessions" "$DEFAULT_SESSIONS_DIR"
  local sessions_path="$REPLY_PATH"
  local sessions_symlink="$REPLY_SYMLINK"

  # Export for store.sh
  export KISS_CLAW_AGENTS_DIR="$agents_path"
  export KISS_CLAW_PROJECT_DIR="$project_path"
  export KISS_CLAW_SESSIONS_DIR="$sessions_path"

  # --- 2.2 Create directory structure ---
  echo ""
  echo "Creating directory structure..."
  mkdir -p "$KC_DIR"
  create_subdir "$agents_path" "$agents_symlink"
  create_subdir "$project_path" "$project_symlink"
  create_subdir "$sessions_path" "$sessions_symlink"

  # --- 2.3 Copy templates ---
  echo ""
  echo "Copying templates..."

  # Project memory
  if [ "$("$STORE" exists memory)" = "true" ]; then
    echo "  skip MEMORY.md (already exists)"
  else
    "$STORE" write memory < "$TEMPLATE_DIR/MEMORY.md.template" > /dev/null
    echo "  created MEMORY.md"
  fi

  # Agent memory files (split from combined template)
  if [ -f "$TEMPLATE_DIR/MEMORY_agents.md.template" ]; then
    for agent in kiss-orchestrator kiss-executor kiss-verificator kiss-improver; do
      if [ "$("$STORE" exists "memory:${agent}")" = "true" ]; then
        echo "  skip MEMORY_${agent}.md (already exists)"
      else
        # Extract the section for this agent from the combined template
        sed -n "/^# MEMORY_${agent}.md/,/^---$/p" "$TEMPLATE_DIR/MEMORY_agents.md.template" \
          | sed '$ { /^---$/d }' \
          | "$STORE" write "memory:${agent}" > /dev/null
        echo "  created MEMORY_${agent}.md"
      fi
    done
  fi

  # --- 2.4 Initialize SESSIONS.json ---
  if [ "$("$STORE" exists sessions)" = "true" ]; then
    echo "  skip SESSIONS.json (already exists)"
  else
    echo '{"sessions":[]}' | "$STORE" write sessions > /dev/null
    echo "  created SESSIONS.json"
  fi

  # --- 2.4b Store claude_sessions_path in SESSIONS.json ---
  # Compute the Claude Code sessions directory path (slug keeps leading dash)
  local claude_slug
  claude_slug="$(pwd | sed 's|/|-|g')"
  local claude_sessions_path="$HOME/.claude/projects/$claude_slug"
  local current_sessions
  current_sessions="$("$STORE" read sessions)"
  local updated_sessions
  updated_sessions="$(echo "$current_sessions" | python3 -c "
import json, sys
data = json.load(sys.stdin)
data['claude_sessions_path'] = '$claude_sessions_path'
print(json.dumps(data, indent=2, ensure_ascii=False))
")"
  echo "$updated_sessions" | "$STORE" write sessions > /dev/null
  echo "  stored claude_sessions_path in SESSIONS.json"

  # --- 2.5 Update .gitignore ---
  echo ""
  if [ -f .gitignore ]; then
    if ! grep -qF "$KC_DIR" .gitignore 2>/dev/null; then
      echo "$KC_DIR" >> .gitignore
      echo "  added $KC_DIR to .gitignore"
    else
      echo "  .gitignore already contains $KC_DIR"
    fi
  else
    echo "$KC_DIR" > .gitignore
    echo "  created .gitignore with $KC_DIR"
  fi

  # --- 2.6 Write layout version ---
  echo "8" > "$KC_DIR/VERSION"
  echo "  wrote VERSION = 8"

  echo ""
  echo "Done. Structure:"
  echo "  $KC_DIR/"
  echo "    agents/    -> $agents_path"
  echo "    project/   -> $project_path"
  echo "    sessions/  -> $sessions_path"
  echo ""
  echo "Next steps:"
  echo "  1. Edit project/MEMORY.md with your project info"
  echo "  2. Start a Claude Code session -- the SessionStart hook will show the agent menu"
}

do_migrate() {
  # --- Check KC_DIR exists ---
  if [[ ! -d "$KC_DIR" ]]; then
    echo "Error: Nothing to migrate — $KC_DIR does not exist."
    exit 1
  fi

  # --- Read current version ---
  local current_version="7"
  if [[ -f "$KC_DIR/VERSION" ]]; then
    current_version="$(cat "$KC_DIR/VERSION")"
  fi

  if [[ "$current_version" = "8" ]]; then
    echo "Already at layout v8 — nothing to do."
    exit 0
  fi

  echo "Migrating $KC_DIR from layout v$current_version to v8..."
  echo ""

  # Resolve sub-directory paths (respect env overrides)
  local agents_dir="${KISS_CLAW_AGENTS_DIR:-$DEFAULT_AGENTS_DIR}"
  local project_dir="${KISS_CLAW_PROJECT_DIR:-$DEFAULT_PROJECT_DIR}"
  local sessions_dir="${KISS_CLAW_SESSIONS_DIR:-$DEFAULT_SESSIONS_DIR}"

  # --- Create sub-directories ---
  mkdir -p "$agents_dir" "$project_dir" "$sessions_dir"
  echo "Created sub-directories: agents/, project/, sessions/"

  local moved=()
  local skipped=()

  # Helper: move file if source exists; skip if target already exists
  move_file() {
    local src="$1"
    local dst="$2"
    if [[ ! -f "$src" ]]; then
      return
    fi
    if [[ -f "$dst" ]]; then
      skipped+=("$src -> $dst (target exists, skipped)")
      return
    fi
    mv "$src" "$dst"
    moved+=("$src -> $dst")
  }

  # --- Move agent files ---
  for f in "$KC_DIR"/MEMORY_kiss-*.md; do
    [[ -f "$f" ]] || continue
    move_file "$f" "$agents_dir/$(basename "$f")"
  done
  move_file "$KC_DIR/INSIGHTS.md" "$agents_dir/INSIGHTS.md"
  move_file "$KC_DIR/ANALYZED.md" "$agents_dir/ANALYZED.md"

  # --- Move project files ---
  move_file "$KC_DIR/MEMORY.md" "$project_dir/MEMORY.md"
  move_file "$KC_DIR/ISSUES.md" "$project_dir/ISSUES.md"

  # --- Move session files ---
  # Determine session name from STATE.md mtime (or fallback to now)
  local session_name
  if [[ -f "$KC_DIR/STATE.md" ]]; then
    session_name="$(date -r "$KC_DIR/STATE.md" '+%Y%m%d-%H%M%S')"
  else
    session_name="$(date '+%Y%m%d-%H%M%S')"
  fi

  local session_dir="$sessions_dir/$session_name"
  local session_files=(PLAN.md STATE.md REVIEWS.md SCRATCH.md CHECKPOINT.md)
  local has_session_files=false

  for f in "${session_files[@]}"; do
    if [[ -f "$KC_DIR/$f" ]]; then
      has_session_files=true
      break
    fi
  done

  if [[ "$has_session_files" = true ]]; then
    mkdir -p "$session_dir"
    for f in "${session_files[@]}"; do
      move_file "$KC_DIR/$f" "$session_dir/$f"
    done
    echo "Created session: $session_name"
  fi

  # --- Initialize SESSIONS.json if missing ---
  if [[ ! -f "$project_dir/SESSIONS.json" ]]; then
    if [[ "$has_session_files" = true ]]; then
      cat > "$project_dir/SESSIONS.json" <<EOJSON
{"sessions":[{"id":"$session_name","created":"$(date -r "$sessions_dir/$session_name" -Iseconds 2>/dev/null || date -Iseconds)"}]}
EOJSON
    else
      echo '{"sessions":[]}' > "$project_dir/SESSIONS.json"
    fi
    echo "Created SESSIONS.json"
  else
    echo "Skipped SESSIONS.json (already exists)"
  fi

  # --- Remove TOKEN_STATS.md (disabled, see ISSUE-006) ---
  if [[ -f "$KC_DIR/TOKEN_STATS.md" ]]; then
    rm "$KC_DIR/TOKEN_STATS.md"
    echo "Removed TOKEN_STATS.md (disabled, see ISSUE-006)"
  fi

  # --- Write VERSION ---
  echo "8" > "$KC_DIR/VERSION"

  # --- Summary ---
  echo ""
  echo "=== Migration summary ==="
  if [[ ${#moved[@]} -gt 0 ]]; then
    echo "Moved:"
    for m in "${moved[@]}"; do
      echo "  $m"
    done
  fi
  if [[ ${#skipped[@]} -gt 0 ]]; then
    echo "Skipped:"
    for s in "${skipped[@]}"; do
      echo "  $s"
    done
  fi
  echo "Layout version: 8"
  echo "========================="
}

# --- main ---

case "${1:-}" in
  --status)
    show_status
    ;;
  --migrate)
    do_migrate
    ;;
  --help|-h)
    echo "Usage: $(basename "$0") [--status|--migrate|--help]"
    echo "  Run from your project root to initialize kiss-claw."
    echo ""
    echo "Options:"
    echo "  --status    Show what's already initialized"
    echo "  --migrate   Migrate v7 (flat) layout to v8 (sub-directories)"
    echo ""
    echo "Environment variables:"
    echo "  KISS_CLAW_DIR          Root directory (default: .kiss-claw)"
    echo "  KISS_CLAW_AGENTS_DIR   Agents sub-directory"
    echo "  KISS_CLAW_PROJECT_DIR  Project sub-directory"
    echo "  KISS_CLAW_SESSIONS_DIR Sessions sub-directory"
    ;;
  "")
    do_init
    ;;
  *)
    echo "Unknown option: $1"
    exit 1
    ;;
esac
