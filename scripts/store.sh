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
    checkpoint)    require_session "$1"; echo "$SESSIONS_DIR/$KISS_CLAW_SESSION/CHECKPOINT.yaml" ;;
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
        for f in "$session_dir"*.md "$session_dir"*.yaml; do
          [[ -f "$f" ]] || continue
          base=$(basename "$f")
          base="${base%.*}"
          result=$(reverse_map "$base" sessions)
          [[ -n "$result" ]] && echo "$result ($session_name)"
        done
      done
    fi
    ;;

  checkpoint)
    SUB="${RESOURCE:?usage: store.sh checkpoint <init-need|upsert> [options...]}"
    case "$SUB" in
      init-need)
        # Parse options
        FORCE=false
        shift 2
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --session) export KISS_CLAW_SESSION="${2:?--session requires a value}"; shift 2 ;;
            --force)   FORCE=true; shift ;;
            *)         echo "error: unknown option: $1" >&2; exit 1 ;;
          esac
        done
        require_session "checkpoint"
        FILE="$SESSIONS_DIR/$KISS_CLAW_SESSION/CHECKPOINT.yaml"
        mkdir -p "$(dirname "$FILE")"

        # Check if need already exists (unless --force)
        if [[ -f "$FILE" ]] && grep -q '^need:' "$FILE" && ! $FORCE; then
          echo "error: need section already exists in checkpoint (use --force to overwrite)" >&2
          exit 1
        fi

        # Read need content from stdin (YAML block with raw, elicited, constraints)
        NEED_CONTENT="$(cat)"

        # Build timestamp
        CREATED="$(date -u +%Y-%m-%dT%H:%M:%S)"

        if [[ -f "$FILE" ]] && $FORCE; then
          # Replace existing need section: remove old need block, write new one
          # Build new file: header + need + preserve log
          LOG_SECTION=""
          if grep -q '^log:' "$FILE"; then
            LOG_SECTION="$(sed -n '/^log:/,$ p' "$FILE")"
          fi
          cat > "$FILE" <<EOF
session: "$KISS_CLAW_SESSION"
created: "$CREATED"

need:
$NEED_CONTENT

${LOG_SECTION:-log: []}
EOF
        else
          # Create fresh checkpoint
          cat > "$FILE" <<EOF
session: "$KISS_CLAW_SESSION"
created: "$CREATED"

need:
$NEED_CONTENT

log: []
EOF
        fi
        echo "ok"
        ;;

      upsert)
        shift 2
        CLAUDE_SESSION="${1:?usage: store.sh checkpoint upsert <claude_session> [--parent <parent_claude_session>]}"
        shift
        PARENT=""
        while [[ $# -gt 0 ]]; do
          case "$1" in
            --parent)  PARENT="${2:?--parent requires a value}"; shift 2 ;;
            --session) export KISS_CLAW_SESSION="${2:?--session requires a value}"; shift 2 ;;
            *)         echo "error: unknown option: $1" >&2; exit 1 ;;
          esac
        done
        require_session "checkpoint"
        FILE="$SESSIONS_DIR/$KISS_CLAW_SESSION/CHECKPOINT.yaml"
        if [[ ! -f "$FILE" ]]; then
          echo "error: checkpoint not found for session $KISS_CLAW_SESSION" >&2
          exit 1
        fi

        # Read fields from stdin (YAML: agent, task/action, result, timestamp)
        STDIN_DATA="$(cat)"

        # Extract fields from stdin YAML (simple single-line or block scalar parsing)
        _extract_field() {
          local field="$1" data="$2"
          local value=""
          # Try single-line first: field: "value" or field: value
          value="$(echo "$data" | sed -n "s/^${field}: *\"\(.*\)\"/\1/p")"
          if [[ -z "$value" ]]; then
            value="$(echo "$data" | sed -n "s/^${field}: *//p")"
          fi
          # Check for block scalar (|)
          if [[ "$value" == "|" ]]; then
            # Collect indented lines following the field declaration
            value="$(echo "$data" | sed -n "/^${field}: *|/,/^[^ ]/{/^${field}:/d;/^[^ ]/d;p;}" | sed 's/^  //')"
          fi
          printf '%s' "$value"
        }

        AGENT="$(_extract_field "agent" "$STDIN_DATA")"
        TIMESTAMP="$(_extract_field "timestamp" "$STDIN_DATA")"
        TASK="$(_extract_field "task" "$STDIN_DATA")"
        ACTION_F="$(_extract_field "action" "$STDIN_DATA")"
        RESULT="$(_extract_field "result" "$STDIN_DATA")"

        # Default timestamp to now if not provided
        if [[ -z "$TIMESTAMP" ]]; then
          TIMESTAMP="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
        fi

        # Check if this claude_session already exists in the file
        if grep -q "claude_session: \"${CLAUDE_SESSION}\"" "$FILE"; then
          # UPDATE mode: replace fields in the existing entry
          # We use a state-machine approach with awk
          awk -v cs="$CLAUDE_SESSION" \
              -v agent="$AGENT" \
              -v timestamp="$TIMESTAMP" \
              -v task="$TASK" \
              -v action="$ACTION_F" \
              -v result="$RESULT" \
          '
          BEGIN { in_entry=0; entry_indent=-1 }
          {
            if ($0 ~ "claude_session: \""cs"\"") {
              in_entry=1
              # Detect indent of the "- agent:" line (2 less than claude_session line)
              match($0, /^[[:space:]]*/)
              entry_indent=RLENGTH
              print
              next
            }
            if (in_entry) {
              match($0, /^[[:space:]]*/)
              cur_len=RLENGTH
              # Exit entry if we hit a line with less indent (parent/sibling scope)
              # or a new list item "- " at same indent as the "- agent:" line
              if (length($0) > 0 && cur_len < entry_indent) {
                in_entry=0
              }
              if (in_entry && $0 ~ /^[[:space:]]*- / && cur_len <= entry_indent - 2) {
                in_entry=0
              }
              if (in_entry) {
                # Update known fields if new values provided (only at entry_indent level)
                if (cur_len == entry_indent) {
                  if (agent != "" && $0 ~ /^[[:space:]]*agent:/) {
                    sub(/agent: .*/, "agent: \""agent"\"")
                  }
                  if (timestamp != "" && $0 ~ /^[[:space:]]*timestamp:/) {
                    sub(/timestamp: .*/, "timestamp: \""timestamp"\"")
                  }
                  if (task != "" && $0 ~ /^[[:space:]]*task:/) {
                    sub(/task: .*/, "task: \""task"\"")
                  }
                  if (action != "" && $0 ~ /^[[:space:]]*action:/) {
                    sub(/action: .*/, "action: \""action"\"")
                  }
                  if (result != "" && $0 ~ /^[[:space:]]*result:/) {
                    sub(/result: .*/, "result: \""result"\"")
                  }
                }
              }
            }
            print
          }
          ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
          echo "ok: updated"
        else
          # INSERT mode: build YAML entry and append

          # Helper: write entry lines to a temp file for safe insertion
          _build_entry() {
            local indent="$1"
            echo "${indent}- agent: \"${AGENT}\""
            echo "${indent}  claude_session: \"${CLAUDE_SESSION}\""
            echo "${indent}  timestamp: \"${TIMESTAMP}\""
            [[ -n "$TASK" ]] && echo "${indent}  task: \"${TASK}\""
            [[ -n "$ACTION_F" ]] && echo "${indent}  action: \"${ACTION_F}\""
            [[ -n "$RESULT" ]] && echo "${indent}  result: \"${RESULT}\""
            echo "${indent}  children: []"
          }

          if [[ -n "$PARENT" ]]; then
            # Find parent entry
            PARENT_LINE="$(grep -n "claude_session: \"${PARENT}\"" "$FILE" | head -1 | cut -d: -f1)"
            if [[ -z "$PARENT_LINE" ]]; then
              echo "error: parent claude_session '$PARENT' not found in checkpoint" >&2
              exit 1
            fi

            # Find the "- agent:" line that starts the parent block
            PARENT_DASH_LINE="$(awk -v pline="$PARENT_LINE" '
              NR<=pline && /^[[:space:]]*- agent:/ { last=NR }
              END { print last }
            ' "$FILE")"
            BASE_INDENT="$(sed -n "${PARENT_DASH_LINE}p" "$FILE" | sed 's/[^ ].*//')"

            # Child indent = parent indent + 4 spaces (children: + list item)
            CHILD_INDENT="${BASE_INDENT}    "

            # Write entry to temp file
            ENTRY_FILE="$(mktemp)"
            _build_entry "$CHILD_INDENT" > "$ENTRY_FILE"

            # Find children: line within this parent block
            CHILDREN_LINE="$(awk -v start="$PARENT_LINE" -v bi="$BASE_INDENT" '
              NR>start {
                # If we hit another top-level list item or unindented key, stop
                match($0, /^[[:space:]]*/)
                ci=substr($0, RSTART, RLENGTH)
                if (length($0)>0 && length(ci) <= length(bi) && $0 ~ /^[[:space:]]*(-|[a-z])/) exit
                if ($0 ~ /children:/) { print NR; exit }
              }
            ' "$FILE")"

            if [[ -n "$CHILDREN_LINE" ]]; then
              CHILDREN_CONTENT="$(sed -n "${CHILDREN_LINE}p" "$FILE")"
              if echo "$CHILDREN_CONTENT" | grep -q '\[\]'; then
                # Replace children: [] with children: and insert entry after
                awk -v cl="$CHILDREN_LINE" -v ef="$ENTRY_FILE" '
                  NR==cl { sub(/children: \[\]/, "children:"); print; while ((getline line < ef) > 0) print line; next }
                  { print }
                ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
              else
                # children: already has entries — find end of children block and append
                END_LINE="$(awk -v start="$CHILDREN_LINE" -v ci="$CHILD_INDENT" '
                  NR>start {
                    if (/^$/) next
                    match($0, /^[[:space:]]*/); cur=substr($0, RSTART, RLENGTH)
                    if (length(cur) < length(ci)) { print NR-1; found=1; exit }
                  }
                  END { if (!found) print NR }
                ' "$FILE")"
                awk -v el="$END_LINE" -v ef="$ENTRY_FILE" '
                  NR==el { print; while ((getline line < ef) > 0) print line; next }
                  { print }
                ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
              fi
            else
              # No children key — add it after the parent block ends
              PARENT_END="$(awk -v start="$PARENT_LINE" -v bi="$BASE_INDENT" '
                NR>start {
                  if (/^$/) next
                  match($0, /^[[:space:]]*/); ci=substr($0, RSTART, RLENGTH)
                  if (length(ci) <= length(bi) && $0 ~ /^[[:space:]]*(-|[a-z])/) { print NR-1; found=1; exit }
                }
                END { if (!found) print NR }
              ' "$FILE")"
              CHILDREN_KEY="${BASE_INDENT}  children:"
              awk -v el="$PARENT_END" -v ck="$CHILDREN_KEY" -v ef="$ENTRY_FILE" '
                NR==el { print; print ck; while ((getline line < ef) > 0) print line; next }
                { print }
              ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
            fi
            rm -f "$ENTRY_FILE"
          else
            # Top-level log entry
            ENTRY_FILE="$(mktemp)"
            _build_entry "  " > "$ENTRY_FILE"

            # Check if log is empty (log: [])
            if grep -q '^log: \[\]' "$FILE"; then
              awk -v ef="$ENTRY_FILE" '
                /^log: \[\]/ { print "log:"; while ((getline line < ef) > 0) print line; next }
                { print }
              ' "$FILE" > "${FILE}.tmp" && mv "${FILE}.tmp" "$FILE"
            else
              # Append at end of file
              cat "$ENTRY_FILE" >> "$FILE"
            fi
            rm -f "$ENTRY_FILE"
          fi
          echo "ok: inserted"
        fi
        ;;

      *)
        echo "unknown checkpoint subcommand: $SUB" >&2
        echo "usage: store.sh checkpoint <init-need|upsert> [options...]" >&2
        exit 1
        ;;
    esac
    ;;

  *)
    echo "unknown action: $ACTION" >&2
    echo "usage: store.sh <read|write|append|update|exists|inspect|list|checkpoint> <resource> [content...]" >&2
    exit 1
    ;;
esac
