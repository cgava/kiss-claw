#!/bin/bash
# Stop hook — suggests available agents if none was activated for this session
# Output is injected into Claude's context, causing it to continue and present the choice

AGENT_FILE=".poc-session-agent"

# If an agent is already active, exit silently
if [[ -f "$AGENT_FILE" ]]; then
  exit 0
fi

# Discover available agents from the plugin's agents/ directory
PLUGIN_ROOT="${CLAUDE_PLUGIN_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
AGENTS_DIR="$PLUGIN_ROOT/agents"

if [[ ! -d "$AGENTS_DIR" ]]; then
  exit 0
fi

# Build agent list with first meaningful line of description from agent.md frontmatter
AGENT_LIST=""
for agent_dir in "$AGENTS_DIR"/*/; do
  agent_name=$(basename "$agent_dir")
  agent_file="$agent_dir/agent.md"
  if [[ -f "$agent_file" ]]; then
    # For multiline YAML (description: |), grab the first indented line after "description:"
    desc=$(awk '/^description:/{
      # Check if value is on same line (not multiline)
      sub(/^description:[[:space:]]*/, "")
      if ($0 != "" && $0 != "|") { print; exit }
      # Multiline: read next indented line
      getline; sub(/^[[:space:]]+/, ""); print; exit
    }' "$agent_file")
    AGENT_LIST="$AGENT_LIST
- **${agent_name}**: ${desc:-no description}"
  fi
done

if [[ -z "$AGENT_LIST" ]]; then
  exit 0
fi

cat <<EOF
[AGENT ROUTING] No agent was activated for this session.

Available agents:
${AGENT_LIST}

Ask the user: "Would you like me to route your request to a specific agent? If so, which one? Otherwise I'll continue as a general session."

If the user picks an agent, write the agent name to the file .poc-session-agent and load the agent's instructions from its agent.md file before continuing.
EOF
