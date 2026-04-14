#!/bin/bash
set -euo pipefail

# sync-sessions.sh — Sync Claude Code sessions to .kiss-claw/claude-sessions/
#
# Usage:
#   ./scripts/sync-sessions.sh [--dry-run] [--clean]
#
# Options:
#   --dry-run   Show what would be done without modifying anything
#   --clean     After sync, prompt to delete source sessions

DRY_RUN=false
CLEAN=false

for arg in "$@"; do
  case "$arg" in
    --dry-run) DRY_RUN=true ;;
    --clean)   CLEAN=true ;;
    -h|--help)
      echo "Usage: $0 [--dry-run] [--clean]"
      echo ""
      echo "Sync Claude Code sessions to .kiss-claw/claude-sessions/"
      echo ""
      echo "Options:"
      echo "  --dry-run   Show what would be done without modifying anything"
      echo "  --clean     After sync, prompt to delete source sessions"
      exit 0
      ;;
    *)
      echo "error: unknown option '$arg'" >&2
      echo "Usage: $0 [--dry-run] [--clean]" >&2
      exit 1
      ;;
  esac
done

# --- 1. Discover project slug ---

PROJECT_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLAUDE_PROJECTS_DIR="$HOME/.claude/projects"

# Build slug: absolute path with / replaced by - (leading slash becomes leading -)
PROJECT_SLUG="${PROJECT_ROOT//\//-}"

SOURCE_DIR="$CLAUDE_PROJECTS_DIR/$PROJECT_SLUG"
KC_DIR="${KISS_CLAW_DIR:-$PROJECT_ROOT/.kiss-claw}"
DEST_DIR="$KC_DIR/sessions/claude-sessions"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "error: Claude sessions directory not found: $SOURCE_DIR" >&2
  echo "hint: expected slug '$PROJECT_SLUG' for project root '$PROJECT_ROOT'" >&2
  exit 1
fi

# --- 2. Count before sync ---

count_jsonl() {
  local dir="$1"
  find "$dir" -maxdepth 1 -name '*.jsonl' 2>/dev/null | wc -l
}

count_subdirs() {
  local dir="$1"
  find "$dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l
}

dir_size_mb() {
  local dir="$1"
  if [[ -d "$dir" ]]; then
    du -sm "$dir" 2>/dev/null | awk '{print $1}'
  else
    echo "0"
  fi
}

SOURCE_TOTAL=$(count_jsonl "$SOURCE_DIR")
SOURCE_SUBDIRS=$(count_subdirs "$SOURCE_DIR")

if [[ "$SOURCE_TOTAL" -eq 0 ]]; then
  echo "No Claude sessions found in $SOURCE_DIR"
  exit 0
fi

# Count existing sessions before sync (for new/updated stats)
EXISTING_BEFORE=0
if [[ -d "$DEST_DIR" ]]; then
  EXISTING_BEFORE=$(count_jsonl "$DEST_DIR")
fi

# --- 3. Sync ---

if [[ "$DRY_RUN" == true ]]; then
  echo "[dry-run] Would create directory: $DEST_DIR"
  echo "[dry-run] Would rsync from: $SOURCE_DIR/"
  echo "[dry-run] Would rsync to:   $DEST_DIR/"
  echo ""
  # Dry-run rsync to show what would transfer
  rsync -av --update --dry-run "$SOURCE_DIR/" "$DEST_DIR/" 2>/dev/null | grep -E '\.jsonl$|/$' | head -50 || true
  echo ""
else
  mkdir -p "$DEST_DIR"
  rsync -av --update "$SOURCE_DIR/" "$DEST_DIR/" > /dev/null 2>&1
fi

# --- 4. Count after sync ---

if [[ "$DRY_RUN" == true ]]; then
  DEST_TOTAL="$SOURCE_TOTAL"
  DEST_SUBDIRS="$SOURCE_SUBDIRS"
  NEW_COUNT=$((SOURCE_TOTAL - EXISTING_BEFORE))
  [[ "$NEW_COUNT" -lt 0 ]] && NEW_COUNT=0
  UPDATED_COUNT="?"
  SIZE_MB=$(dir_size_mb "$SOURCE_DIR")
else
  DEST_TOTAL=$(count_jsonl "$DEST_DIR")
  DEST_SUBDIRS=$(count_subdirs "$DEST_DIR")
  NEW_COUNT=$((DEST_TOTAL - EXISTING_BEFORE))
  [[ "$NEW_COUNT" -lt 0 ]] && NEW_COUNT=0
  UPDATED_COUNT="--"
  SIZE_MB=$(dir_size_mb "$DEST_DIR")
fi

# --- 5. Report ---

DRY_PREFIX=""
[[ "$DRY_RUN" == true ]] && DRY_PREFIX="[dry-run] "

echo ""
echo "${DRY_PREFIX}=== SYNC REPORT ==="
echo "${DRY_PREFIX}Source     : $SOURCE_DIR/"
echo "${DRY_PREFIX}Dest       : $DEST_DIR/"
echo "${DRY_PREFIX}Sessions   : $DEST_TOTAL total ($NEW_COUNT new)"
echo "${DRY_PREFIX}Sub-agents : $DEST_SUBDIRS directories"
echo "${DRY_PREFIX}Size       : ${SIZE_MB} MB"
echo "${DRY_PREFIX}==================="

# --- 6. Clean (optional) ---

if [[ "$CLEAN" == true ]]; then
  echo ""

  # List source .jsonl files
  JSONL_FILES=()
  while IFS= read -r f; do
    JSONL_FILES+=("$f")
  done < <(find "$SOURCE_DIR" -maxdepth 1 -name '*.jsonl' -type f | sort)

  JSONL_COUNT=${#JSONL_FILES[@]}

  if [[ "$JSONL_COUNT" -eq 0 ]]; then
    echo "No source sessions to clean."
    exit 0
  fi

  if [[ "$DRY_RUN" == true ]]; then
    echo "[dry-run] Would delete $JSONL_COUNT .jsonl files from $SOURCE_DIR/"
    echo "[dry-run] Would also delete $SOURCE_SUBDIRS sub-agent directories"
    echo "[dry-run] Files that would be deleted:"
    for f in "${JSONL_FILES[@]}"; do
      echo "  [dry-run] $(basename "$f")"
    done
    # Also list directories
    while IFS= read -r d; do
      echo "  [dry-run] $(basename "$d")/"
    done < <(find "$SOURCE_DIR" -maxdepth 1 -mindepth 1 -type d | sort)
    exit 0
  fi

  echo "Delete $JSONL_COUNT sessions (and $SOURCE_SUBDIRS sub-agent dirs) from source?"
  echo "  Source: $SOURCE_DIR/"
  printf "  Confirm (y/N): "
  read -r CONFIRM

  if [[ "$CONFIRM" == "y" || "$CONFIRM" == "Y" ]]; then
    # Delete .jsonl files
    for f in "${JSONL_FILES[@]}"; do
      rm -f "$f"
    done
    # Delete sub-agent directories
    find "$SOURCE_DIR" -maxdepth 1 -mindepth 1 -type d -exec rm -rf {} +
    echo "Deleted $JSONL_COUNT sessions and $SOURCE_SUBDIRS sub-agent directories."
  else
    echo "Aborted. No files deleted."
  fi
fi
