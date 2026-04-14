#!/bin/bash
set -euo pipefail

ACTION="${1:?usage: store.sh <action> <resource> [content...]}"
RESOURCE="${2:-}"
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"
AGENTS_DIR="${KISS_CLAW_AGENTS_DIR:-$KC_DIR/agents}"
PROJECT_DIR="${KISS_CLAW_PROJECT_DIR:-$KC_DIR/project}"
SESSIONS_DIR="${KISS_CLAW_SESSIONS_DIR:-$KC_DIR/sessions}"

# Require KISS_CLAW_SESSION for session-scoped resources
require_session() {
  if [[ -z "${KISS_CLAW_SESSION:-}" ]]; then
    echo "error: KISS_CLAW_SESSION is required for resource '$1' (session-scoped)" >&2
    exit 1
  fi
}

# Resolve resource name to file path
resolve() {
  case "$1" in
    # session-scoped resources
    plan)          require_session "$1"; echo "$SESSIONS_DIR/$KISS_CLAW_SESSION/PLAN.md" ;;
    state)         require_session "$1"; echo "$SESSIONS_DIR/$KISS_CLAW_SESSION/STATE.md" ;;
    reviews)       require_session "$1"; echo "$SESSIONS_DIR/$KISS_CLAW_SESSION/REVIEWS.md" ;;
    scratch)       require_session "$1"; echo "$SESSIONS_DIR/$KISS_CLAW_SESSION/SCRATCH.md" ;;
    checkpoint)    require_session "$1"; echo "$SESSIONS_DIR/$KISS_CLAW_SESSION/CHECKPOINT.md" ;;
    # agent-scoped resources
    memory:kiss-*) echo "$AGENTS_DIR/MEMORY_${1#memory:}.md" ;;
    insights)      echo "$AGENTS_DIR/INSIGHTS.md" ;;
    analyzed)      echo "$AGENTS_DIR/ANALYZED.md" ;;
    # project-scoped resources
    memory)        echo "$PROJECT_DIR/MEMORY.md" ;;
    sessions)      echo "$PROJECT_DIR/SESSIONS.json" ;;
    *)             echo "unknown resource: $1" >&2; exit 1 ;;
  esac
}

# Reverse mapping: filename (without extension) to resource name
# Second arg is the category (agents|project|sessions)
reverse_map() {
  local base="$1"
  local category="${2:-}"
  case "$category" in
    agents)
      case "$base" in
        MEMORY_kiss-*) echo "memory:${base#MEMORY_}" ;;
        INSIGHTS)      echo "insights" ;;
        ANALYZED)      echo "analyzed" ;;
        *)             ;; # skip unknown
      esac
      ;;
    project)
      case "$base" in
        MEMORY)        echo "memory" ;;
        SESSIONS)      echo "sessions" ;;
        *)             ;; # skip unknown
      esac
      ;;
    sessions)
      case "$base" in
        PLAN)          echo "plan" ;;
        STATE)         echo "state" ;;
        REVIEWS)       echo "reviews" ;;
        SCRATCH)       echo "scratch" ;;
        CHECKPOINT)    echo "checkpoint" ;;
        *)             ;; # skip unknown
      esac
      ;;
    *)
      ;; # skip unknown category
  esac
}

case "$ACTION" in
  read)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh read <resource>" >&2; exit 1; }
    FILE=$(resolve "$RESOURCE")
    [[ -f "$FILE" ]] && cat "$FILE" || true
    ;;

  write)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh write <resource> [content...]" >&2; exit 1; }
    FILE=$(resolve "$RESOURCE")
    mkdir -p "$(dirname "$FILE")"
    # Content = everything after resource ($3 $4 $5 ...)
    shift 2
    CONTENT="$*"
    if [[ -n "$CONTENT" ]]; then
      printf '%s\n' "$CONTENT" > "$FILE"
    else
      cat > "$FILE"
    fi
    echo "ok"
    ;;

  append)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh append <resource> [content...]" >&2; exit 1; }
    FILE=$(resolve "$RESOURCE")
    mkdir -p "$(dirname "$FILE")"
    shift 2
    CONTENT="$*"
    if [[ -n "$CONTENT" ]]; then
      printf '%s\n' "$CONTENT" >> "$FILE"
    else
      cat >> "$FILE"
    fi
    echo "ok"
    ;;

  update)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh update <resource> <field> <value...>" >&2; exit 1; }
    FILE=$(resolve "$RESOURCE")
    FIELD="${3:?usage: store.sh update <resource> <field> <value...>}"
    if [[ ! -f "$FILE" ]]; then
      echo "resource not found: $RESOURCE" >&2
      exit 1
    fi
    # Value = everything after field ($4 $5 $6 ...)
    shift 3
    VALUE="$*"
    # Escape sed special chars in field name to prevent regex injection
    ESCAPED_FIELD=$(printf '%s' "$FIELD" | sed 's/[][\.*^$/]/\\&/g')
    # Escape sed special chars in value to prevent injection (& and \ are special in replacement)
    ESCAPED_VALUE=$(printf '%s' "$VALUE" | sed 's/[&\\/]/\\&/g')
    sed -i "s/^${ESCAPED_FIELD}:.*/${ESCAPED_FIELD}: \"${ESCAPED_VALUE}\"/" "$FILE"
    echo "ok"
    ;;

  exists)
    [[ -z "$RESOURCE" ]] && { echo "usage: store.sh exists <resource>" >&2; exit 1; }
    FILE=$(resolve "$RESOURCE")
    [[ -f "$FILE" ]] && echo "true" || echo "false"
    ;;

  inspect)
    echo "kiss_claw_dir: $KC_DIR"
    echo "agents_dir: $AGENTS_DIR"
    echo "project_dir: $PROJECT_DIR"
    echo "sessions_dir: $SESSIONS_DIR"
    echo "session: ${KISS_CLAW_SESSION:-<not set>}"
    if [[ -n "${KISS_CLAW_SESSION:-}" ]]; then
      echo "session_path: $SESSIONS_DIR/$KISS_CLAW_SESSION"
    fi
    echo "---"
    echo "Resources:"
    for r in plan state reviews scratch checkpoint; do
      if [[ -n "${KISS_CLAW_SESSION:-}" ]]; then
        echo "  $r: $(resolve "$r" 2>/dev/null)"
      else
        echo "  $r: (requires session)"
      fi
    done
    for r in memory insights analyzed sessions; do
      echo "  $r: $(resolve "$r" 2>/dev/null)"
    done
    ;;

  list)
    # Scan agents directory
    for f in "$AGENTS_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f" .md)
      result=$(reverse_map "$base" agents)
      [[ -n "$result" ]] && echo "$result"
    done
    # Scan project directory
    for f in "$PROJECT_DIR"/*.md "$PROJECT_DIR"/*.json; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f")
      base="${base%.*}"
      result=$(reverse_map "$base" project)
      [[ -n "$result" ]] && echo "$result"
    done
    # Scan sessions directory (all sessions)
    if [[ -d "$SESSIONS_DIR" ]]; then
      for session_dir in "$SESSIONS_DIR"/*/; do
        [[ -d "$session_dir" ]] || continue
        session_name=$(basename "$session_dir")
        for f in "$session_dir"*.md; do
          [[ -f "$f" ]] || continue
          base=$(basename "$f" .md)
          result=$(reverse_map "$base" sessions)
          [[ -n "$result" ]] && echo "$result ($session_name)"
        done
      done
    fi
    ;;

  *)
    echo "unknown action: $ACTION" >&2
    echo "usage: store.sh <read|write|append|update|exists|inspect|list> <resource> [content...]" >&2
    exit 1
    ;;
esac
