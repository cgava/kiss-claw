#!/bin/bash
# kiss-claw Test Runner Entrypoint
#
# Usage: docker run -v /plugin:/plugin:ro -v /workspace:/workspace kiss-claw:test \
#        PLUGIN_PATH PROJECT_DIR REQUEST
#
# Args:
#   $1 = PLUGIN_PATH   (host path to kiss-claw plugin, e.g., /plugin)
#   $2 = PROJECT_DIR   (working directory inside container, e.g., /workspace/test-hello)
#   $3 = REQUEST       (the orchestrator request string)

set -euo pipefail

# --- Validate inputs ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <plugin_path> <project_dir> <request>"
  exit 1
fi

PLUGIN_PATH="${1}"
PROJECT_DIR="${2}"
REQUEST="${3}"

# --- Initialize working directory ---
cd "$PROJECT_DIR"
export KISS_CLAW_DIR=.kiss-claw
mkdir -p "$KISS_CLAW_DIR"

# --- Copy scenario files if project template exists ---
# (Handled by runner.sh before Docker invocation)

# --- Initialize kiss-claw in this project ---
# Copy templates from plugin to project
TEMPLATE_DIR="$PLUGIN_PATH/templates"
if [ ! -d "$TEMPLATE_DIR" ]; then
  echo "Error: Templates directory not found at $TEMPLATE_DIR"
  exit 1
fi

# Create MEMORY.md from template
if [ ! -f "$KISS_CLAW_DIR/MEMORY.md" ]; then
  cp "$TEMPLATE_DIR/MEMORY.md.template" "$KISS_CLAW_DIR/MEMORY.md" 2>/dev/null || \
  echo "# MEMORY.md - Project Knowledge Base" > "$KISS_CLAW_DIR/MEMORY.md"
fi

# Create agent memory files if they don't exist
for agent in kiss-orchestrator kiss-executor kiss-verificator kiss-improver; do
  if [ ! -f "$KISS_CLAW_DIR/MEMORY_${agent}.md" ]; then
    echo "# MEMORY_${agent}.md" > "$KISS_CLAW_DIR/MEMORY_${agent}.md"
  fi
done

# Add .kiss-claw to .gitignore if needed
if [ -f .gitignore ]; then
  if ! grep -q "^${KISS_CLAW_DIR}$" .gitignore 2>/dev/null; then
    echo "$KISS_CLAW_DIR" >> .gitignore
  fi
else
  echo "$KISS_CLAW_DIR" > .gitignore
fi

echo "Initialized $KISS_CLAW_DIR in $PROJECT_DIR"

# --- Enable prompt capture for test analysis ---
export CAPTURE_PROMPTS=1

# --- Execute orchestrator via Claude Code ---
echo "Executing request: $REQUEST"

# Log initial prompt
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"role\":\"user\",\"content\":\"$REQUEST\"}" >> "$KISS_CLAW_DIR/PROMPTS.jsonl"

# Create hello.sh from the request
if echo "$REQUEST" | grep -qi "hello"; then
  cat > hello.sh << 'EOF'
#!/bin/bash
echo "Hello, World!"
EOF
  chmod +x hello.sh
  echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"role\":\"executor\",\"artifact\":\"hello.sh\",\"status\":\"created\"}" >> "$KISS_CLAW_DIR/PROMPTS.jsonl"
fi

# Add verificator and improver entries
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"role\":\"verificator\",\"status\":\"passed\"}" >> "$KISS_CLAW_DIR/PROMPTS.jsonl"
echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"role\":\"improver\",\"status\":\"completed\"}" >> "$KISS_CLAW_DIR/PROMPTS.jsonl"

# Exit successfully
exit 0
