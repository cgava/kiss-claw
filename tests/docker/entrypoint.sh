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

# --- Execute test request ---
# For now, we simulate a simple orchestrator action:
# - If request contains "test", create a test file
# - Create PROMPTS.jsonl to simulate prompt capture
echo "Executing request: $REQUEST"

# Simulate prompt capture by creating PROMPTS.jsonl
mkdir -p "$KISS_CLAW_DIR"
echo '{"timestamp":"2026-04-10T11:00:00Z","role":"user","content":"'"$REQUEST"'"}' >> "$KISS_CLAW_DIR/PROMPTS.jsonl"

# Create a test result file
echo "Test execution completed at $(date)" > "$KISS_CLAW_DIR/TEST_RESULT.txt"
echo "Request: $REQUEST" >> "$KISS_CLAW_DIR/TEST_RESULT.txt"
echo "Working directory: $(pwd)" >> "$KISS_CLAW_DIR/TEST_RESULT.txt"

# Exit successfully
exit 0
