#!/bin/bash
# kiss-claw Docker build and smoke test
#
# Run from the kiss-claw repo root.
#
# Usage:
#   ./tests/docker/build-and-test.sh [commit_sha]
#   GIT_REMOTE_URL=git@github.com:user/repo.git ./tests/docker/build-and-test.sh --ssh [commit_sha]
#
# Options:
#   $1          — commit SHA to checkout inside container (default: current HEAD)
#   --ssh       — forward SSH agent for remote clone testing
#                 Requires: GIT_REMOTE_URL env var set to the remote repo URL
#                 Requires: SSH_AUTH_SOCK to be available (ssh-agent running)
#
# Environment variables:
#   GIT_REMOTE_URL — remote repo URL for SSH clone (e.g., git@github.com:user/kiss-claw.git)
#                    Required when using --ssh.
#
# Examples:
#   ./tests/docker/build-and-test.sh                    # local clone, HEAD
#   ./tests/docker/build-and-test.sh abc1234            # local clone, specific commit
#   GIT_REMOTE_URL=git@github.com:user/kiss-claw.git \
#     ./tests/docker/build-and-test.sh --ssh            # remote clone via SSH agent
#   GIT_REMOTE_URL=git@github.com:user/kiss-claw.git \
#     ./tests/docker/build-and-test.sh --ssh abc1234    # remote clone, specific commit

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

# Validate --ssh requires GIT_REMOTE_URL
if [ "$USE_SSH" = true ] && [ -z "${GIT_REMOTE_URL:-}" ]; then
  echo "ERROR: --ssh requires GIT_REMOTE_URL to be set."
  echo "Usage: GIT_REMOTE_URL=git@github.com:user/repo.git $0 --ssh [commit]"
  exit 1
fi

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
    -e GIT_REMOTE_URL="$GIT_REMOTE_URL"
  )
else
  if [ "$USE_SSH" = true ]; then
    echo "ERROR: --ssh requested but SSH_AUTH_SOCK is not set (is ssh-agent running?)"
    exit 1
  fi
fi

docker run "${DOCKER_ARGS[@]}" "$IMAGE_NAME" "$COMMIT"

echo ""
echo "=== Smoke test passed ==="
