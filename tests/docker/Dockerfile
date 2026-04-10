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

# Environment and entrypoint
ENV KISS_CLAW_DIR=.kiss-claw

# Create a wrapper that forwards all arguments to the mounted entrypoint script
RUN mkdir -p /tmp && cat > /tmp/entrypoint-wrapper.sh << 'EOF'
#!/bin/bash
exec bash /plugin/tests/docker/entrypoint.sh "$@"
EOF
RUN chmod +x /tmp/entrypoint-wrapper.sh

# Use the wrapper to properly forward arguments
ENTRYPOINT ["/tmp/entrypoint-wrapper.sh"]
