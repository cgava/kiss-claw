#!/bin/bash
# kiss-claw Test Runner Entrypoint
#
# Purpose: Clone repo at a specific commit, prepare environment, validate setup.
# Phase 4 will add the Python test runner invocation.
#
# Usage: docker run --rm \
#   -v <kiss-claw-repo>:/repo-source:ro \
#   -v ~/.claude:/root/.claude:ro \
#   kiss-claw-test [commit_sha]
#
# Environment variables:
#   KISS_COMMIT      — commit to checkout (default: HEAD). Arg $1 overrides this.
#   GIT_REMOTE_URL   — remote repo URL for SSH clone (e.g., git@github.com:user/kiss-claw.git)
#   SSH_AUTH_SOCK    — if set, enables SSH agent forwarding for remote clone
#
# Clone source priority:
#   1. If GIT_REMOTE_URL is set and SSH_AUTH_SOCK is available: clone from remote
#   2. Otherwise: clone from file:///repo-source (local mount)

set -euo pipefail

# --- Activate Python venv ---
source /opt/test-venv/bin/activate

# --- Determine commit ---
COMMIT="${1:-${KISS_COMMIT:-HEAD}}"

# --- Determine clone source ---
if [ -n "${GIT_REMOTE_URL:-}" ] && [ -n "${SSH_AUTH_SOCK:-}" ]; then
  CLONE_SOURCE="$GIT_REMOTE_URL"
  echo "Clone source: remote ($CLONE_SOURCE) via SSH agent"
  # Populate known_hosts at runtime (not baked into image)
  echo "Fetching SSH host keys for github.com ..."
  mkdir -p /root/.ssh
  ssh-keyscan -t ed25519,rsa github.com >> /root/.ssh/known_hosts 2>/dev/null
  chmod 600 /root/.ssh/known_hosts
else
  CLONE_SOURCE="file:///repo-source"
  # Verify local mount exists
  if [ ! -d /repo-source/.git ]; then
    echo "ERROR: /repo-source not mounted or not a git repo"
    echo "Mount with: -v <repo-path>:/repo-source:ro"
    exit 1
  fi
  echo "Clone source: local mount ($CLONE_SOURCE)"
fi

# --- Clean workspace and clone ---
rm -rf /workspace/*
cd /workspace

echo "Cloning from $CLONE_SOURCE ..."
git clone "$CLONE_SOURCE" .

# --- Checkout specific commit ---
if [ "$COMMIT" != "HEAD" ]; then
  echo "Checking out commit: $COMMIT"
  git checkout "$COMMIT" --quiet
fi

echo "Repo at: $(git rev-parse --short HEAD) ($(git log -1 --format='%s'))"

# --- Validate environment ---
echo ""
echo "=== kiss-claw test environment ==="
echo "Python : $(python3 --version)"
echo "Claude : $(claude --version)"
echo "Workdir: $(pwd)"
echo "Commit : $(git rev-parse HEAD)"

# Verify OAuth tokens mount
if [ -d /root/.claude ]; then
  echo "OAuth mount : OK"
else
  echo "WARNING: /root/.claude not mounted -- claude CLI auth may fail"
fi

echo "=== environment validated ==="
exit 0
