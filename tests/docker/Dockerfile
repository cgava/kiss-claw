# kiss-claw Test Runner - Minimal Docker image
# Base: debian:stable-slim (lightweight)
# Purpose: Execute kiss-claw test scenarios in isolated containers

FROM debian:stable-slim

# System packages - minimal essentials
RUN apt-get update && apt-get install -y --no-install-recommends \
  bash \
  git \
  curl \
  jq \
  ca-certificates \
  npm \
  && rm -rf /var/lib/apt/lists/*

# Install Claude CLI globally
RUN npm install -g @anthropic-ai/claude-code

# Create workspace directory for test projects
WORKDIR /workspace

# Copy kiss-claw plugin source (mounted at /plugin in container)
# This allows the entrypoint to initialize kiss-claw in test projects
ENV KISS_CLAW_DIR=.kiss-claw

# Set entrypoint to orchestration script
COPY entrypoint.sh /entrypoint.sh
RUN chmod +x /entrypoint.sh

ENTRYPOINT ["/entrypoint.sh"]
