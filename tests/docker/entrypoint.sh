#!/bin/bash
# kiss-claw Test Runner Entrypoint
#
# Usage: docker run -v /plugin:/plugin -v /workspace:/workspace kiss-claw:test \
#        SCENARIO_PATH PROJECT_DIR REQUEST
#
# Args:
#   $1 = SCENARIO_PATH (host path to scenario definition, e.g., /scenario)
#   $2 = PROJECT_DIR   (working directory inside container, e.g., /workspace/test-hello)
#   $3 = REQUEST       (the orchestrator request string)

set -euo pipefail

# --- Validate inputs ---
if [ $# -lt 3 ]; then
  echo "Usage: $0 <scenario_path> <project_dir> <request>"
  exit 1
fi

SCENARIO_PATH="${1}"
PROJECT_DIR="${2}"
REQUEST="${3}"

# --- Initialize working directory ---
cd "$PROJECT_DIR"
export KISS_CLAW_DIR=.kiss-claw
mkdir -p "$KISS_CLAW_DIR"

# --- Copy scenario files if project template exists ---
if [ -d "${SCENARIO_PATH}/project" ]; then
  cp -r "${SCENARIO_PATH}/project"/* . || true
fi

# --- Initialize kiss-claw in this project ---
if [ -d /plugin/scripts ]; then
  bash /plugin/scripts/init.sh
else
  echo "Error: /plugin/scripts/init.sh not found"
  exit 1
fi

# --- Enable prompt capture for test analysis ---
export CAPTURE_PROMPTS=1

# --- Execute orchestrator request ---
# The orchestrator agent.md is at /plugin/agents/kiss-orchestrator/agent.md
# We invoke it as a shell script with the 'request' subcommand
if [ -f /plugin/agents/kiss-orchestrator/agent.md ]; then
  bash /plugin/agents/kiss-orchestrator/agent.md request "$REQUEST"
else
  echo "Error: /plugin/agents/kiss-orchestrator/agent.md not found"
  exit 1
fi

# --- Exit with orchestrator's exit code ---
exit $?
