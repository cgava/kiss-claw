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
  python3 \
  python3-venv \
  && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create Python venv (stdlib only, no pip install needed)
RUN python3 -m venv /opt/test-venv

WORKDIR /workspace

# Mount points (documented, not baked in):
#   -v <host-kiss-claw>:/plugin:ro        — plugin source
#   -v ~/.claude:/root/.claude:ro          — OAuth tokens

ENV KISS_CLAW_DIR=.kiss-claw

COPY entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

ENTRYPOINT ["/usr/local/bin/entrypoint.sh"]
