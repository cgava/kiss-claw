#!/bin/bash
set -euo pipefail

ACTION="${1:?usage: store.sh <action> <resource> [content...]}"
RESOURCE="${2:-}"
KC_DIR="${KISS_CLAW_DIR:-.kiss-claw}"

# Resolve resource name to file path
resolve() {
  case "$1" in
    plan)          echo "$KC_DIR/PLAN.md" ;;
    state)         echo "$KC_DIR/STATE.md" ;;
    scratch)       echo "$KC_DIR/SCRATCH.md" ;;
    memory)        echo "$KC_DIR/MEMORY.md" ;;
    memory:*)      echo "$KC_DIR/MEMORY_${1#memory:}.md" ;;
    reviews)       echo "$KC_DIR/REVIEWS.md" ;;
    insights)      echo "$KC_DIR/INSIGHTS.md" ;;
    analyzed)      echo "$KC_DIR/ANALYZED.md" ;;
    token-stats)   echo "$KC_DIR/TOKEN_STATS.md" ;;
    checkpoint)    echo "$KC_DIR/CHECKPOINT.md" ;;
    *)             echo "unknown resource: $1" >&2; exit 1 ;;
  esac
}

# Reverse mapping: filename (without .md) to resource name
reverse_map() {
  case "$1" in
    PLAN)          echo "plan" ;;
    STATE)         echo "state" ;;
    SCRATCH)       echo "scratch" ;;
    MEMORY)        echo "memory" ;;
    MEMORY_*)      echo "memory:${1#MEMORY_}" ;;
    REVIEWS)       echo "reviews" ;;
    INSIGHTS)      echo "insights" ;;
    ANALYZED)      echo "analyzed" ;;
    TOKEN_STATS)   echo "token-stats" ;;
    CHECKPOINT)    echo "checkpoint" ;;
    *)             ;; # skip unknown files silently
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

  list)
    for f in "$KC_DIR"/*.md; do
      [[ -f "$f" ]] || continue
      base=$(basename "$f" .md)
      result=$(reverse_map "$base")
      [[ -n "$result" ]] && echo "$result"
    done
    ;;

  *)
    echo "unknown action: $ACTION" >&2
    echo "usage: store.sh <read|write|append|update|exists|list> <resource> [content...]" >&2
    exit 1
    ;;
esac
