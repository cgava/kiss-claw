#!/bin/bash
# kiss-claw Docker build and smoke test
#
# Usage: ./tests/docker/build-and-test.sh
# Run from the kiss-claw repo root.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
IMAGE_NAME="kiss-claw-test"

echo "=== Building Docker image ==="
docker build -t "$IMAGE_NAME" "$REPO_ROOT/tests/docker/"

echo ""
echo "=== Running smoke test ==="
docker run --rm \
  -v "$REPO_ROOT":/plugin:ro \
  -v "$HOME/.claude":/root/.claude:ro \
  "$IMAGE_NAME"

echo ""
echo "=== Smoke test passed ==="
