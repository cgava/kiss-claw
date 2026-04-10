# kiss-claw Test Runner - Docker image
# Base: debian:stable-slim
# Purpose: Python + Claude CLI environment for functional tests

FROM debian:stable-slim

# System packages + Python 3 with venv support
RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  git \
  curl \
  jq \
  ca-certificates \
  npm \
  openssh-client \
  python3 \
  python3-venv \
  && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create Python venv (stdlib only, no pip install needed)
RUN python3 -m venv /opt/test-venv

WORKDIR /workspace

# Mount points (documented, not baked in):
#   -v <host-kiss-claw>:/repo-source:ro    — repo source for git clone
#   -v ~/.claude:/root/.claude:ro          — OAuth tokens
#   -v $SSH_AUTH_SOCK:/ssh-agent           — (optional) SSH agent forwarding

# Pre-populate known_hosts for github.com (needed for SSH clone)
RUN mkdir -p /root/.ssh && \
  ssh-keyscan -t ed25519,rsa github.com >> /root/.ssh/known_hosts 2>/dev/null && \
  chmod 600 /root/.ssh/known_hosts

ENV KISS_CLAW_DIR=.kiss-claw

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
