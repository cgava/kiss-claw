#!/bin/bash
# kiss-claw Docker build and smoke test
#
# Usage: ./tests/docker/build-and-test.sh [commit_sha]
# Run from the kiss-claw repo root.
#
# Options:
#   $1          — commit SHA to checkout inside container (default: current HEAD)
#   --ssh       — forward SSH agent for remote clone testing
#
# Examples:
#   ./tests/docker/build-and-test.sh                    # local clone, HEAD
#   ./tests/docker/build-and-test.sh abc1234            # local clone, specific commit
#   ./tests/docker/build-and-test.sh --ssh              # remote clone via SSH agent

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE_NAME="kiss-claw-test"
COMMIT=""
USE_SSH=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --ssh) USE_SSH=true ;;
    *)     COMMIT="$arg" ;;
  esac
done

# Default commit: current HEAD
if [ -z "$COMMIT" ]; then
  COMMIT="$(git -C "$REPO_ROOT" rev-parse HEAD)"
fi

echo "=== Building Docker image ==="
docker build -t "$IMAGE_NAME" "$REPO_ROOT/tests/docker/"

echo ""
echo "=== Running smoke test ==="
echo "Commit: $COMMIT"

# Build docker run command
DOCKER_ARGS=(
  --rm
  -v "$REPO_ROOT":/repo-source:ro
  -v "$HOME/.claude":/root/.claude:ro
)

# Optionally forward SSH agent
if [ "$USE_SSH" = true ] && [ -n "${SSH_AUTH_SOCK:-}" ]; then
  echo "SSH agent: forwarding"
  DOCKER_ARGS+=(
    -v "$SSH_AUTH_SOCK":/ssh-agent
    -e SSH_AUTH_SOCK=/ssh-agent
  )
else
  if [ "$USE_SSH" = true ]; then
    echo "WARNING: --ssh requested but SSH_AUTH_SOCK is not set"
  fi
fi

docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" "$COMMIT"

echo ""
echo "=== Smoke test passed ==="
