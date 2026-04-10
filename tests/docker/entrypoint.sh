#!/bin/bash
# kiss-claw Test Runner Entrypoint
#
# Purpose: Prepare environment and validate setup.
# Phase 4 will add the Python test runner invocation.
#
# Usage: docker run --rm \
#   -v <kiss-claw-repo>:/plugin:ro \
#   -v ~/.claude:/root/.claude:ro \
#   kiss-claw-test [scenario_path]
#
# Args:
#   $1 = test scenario path (optional, unused until Phase 4)

set -euo pipefail

# --- Activate Python venv ---
source /opt/test-venv/bin/activate

# --- Validate environment ---
echo "=== kiss-claw test environment ==="
echo "Python : $(python3 --version)"
echo "Claude : $(claude --version)"
echo "Workdir: $(pwd)"
echo "Plugin : /plugin"

# Verify plugin mount exists
if [ -d /plugin ]; then
  echo "Plugin mount: OK"
else
  echo "WARNING: /plugin not mounted — tests will not have access to kiss-claw source"
fi

# Verify OAuth tokens mount
if [ -d /root/.claude ]; then
  echo "OAuth mount : OK"
else
  echo "WARNING: /root/.claude not mounted — claude CLI auth may fail"
fi

# --- Copy kiss-claw plugin config if needed ---
if [ -d /plugin/.kiss-claw ] && [ ! -d .kiss-claw ]; then
  cp -r /plugin/.kiss-claw .kiss-claw
  echo "Copied .kiss-claw config from plugin mount"
fi

# --- Report scenario arg (Phase 4 will use it) ---
if [ -n "${1:-}" ]; then
  echo "Scenario: $1 (will be used by Python runner in Phase 4)"
fi

echo "=== environment validated ==="
exit 0
