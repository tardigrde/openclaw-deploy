###############################################################################
# OpenClaw Gateway – Docker Image
#
# IMPORTANT: Runtime installs are lost on container restart. All binaries
# needed by skills MUST be installed here at build time. If you add a skill
# that needs a new binary, update this Dockerfile and rebuild.
#
# NOTE: Chromium is NOT installed here — the separate chromedp/headless-shell
# container provides browser automation via the agent-browser skill.
###############################################################################

# checkov:skip=CKV_DOCKER_2:No suitable health endpoint available in this container
FROM node:24-bookworm-slim

# Install runtime dependencies + GitHub CLI in a single layer
# gnupg is installed only to import the GH CLI signing key, then removed
RUN apt-get update && apt-get install -y --no-install-recommends \
    git \
    curl \
    ca-certificates \
    gnupg \
    openssh-client \
    python3 \
    age \
  && curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg \
      | dd of=/usr/share/keyrings/githubcli-archive-keyring.gpg \
  && chmod 644 /usr/share/keyrings/githubcli-archive-keyring.gpg \
  && echo "deb [arch=$(dpkg --print-architecture) signed-by=/usr/share/keyrings/githubcli-archive-keyring.gpg] https://cli.github.com/packages stable main" \
      > /etc/apt/sources.list.d/github-cli.list \
  && apt-get update && apt-get install -y --no-install-recommends gh \
  && apt-get purge -y --auto-remove gnupg \
  && rm -rf /var/lib/apt/lists/*

# Install SOPS (for native secrets decryption via exec provider)
ARG SOPS_VERSION=3.9.4
ARG SOPS_SHA256=5488e32bc471de7982ad895dd054bbab3ab91c417a118426134551e9626e4e85  # amd64 only
RUN curl -fsSL "https://github.com/getsops/sops/releases/download/v${SOPS_VERSION}/sops-v${SOPS_VERSION}.linux.amd64" \
      -o /usr/local/bin/sops \
  && echo "${SOPS_SHA256}  /usr/local/bin/sops" | sha256sum --check \
  && chmod +x /usr/local/bin/sops

# Install uv (Python package manager) — manages Python versions and project deps
ARG UV_VERSION=0.6.6
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh \
  && mv /root/.local/bin/uv /usr/local/bin/uv \
  && mv /root/.local/bin/uvx /usr/local/bin/uvx \
  && rm -rf /root/.local

# Pin OpenClaw version for reproducible builds — bump explicitly when upgrading
ARG OPENCLAW_VERSION=2026.3.13
RUN npm install -g \
    openclaw@${OPENCLAW_VERSION} \
    clawhub \
    @steipete/summarize \
    ws

# Create OpenClaw directories owned by node
RUN mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node/.openclaw /.clawhub

# Copy skills manifest, workspace templates, agent templates, and entrypoint
COPY docker/skills-manifest.txt /opt/config/skills-manifest.txt
COPY docker/workspace-templates/ /opt/workspace-templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node

# Set git identity for agent commits
ARG GIT_USER_NAME="OpenClaw"
ARG GIT_USER_EMAIL="openclaw@users.noreply.local"
RUN git config --global user.name "${GIT_USER_NAME}" \
 && git config --global user.email "${GIT_USER_EMAIL}"

# Make globally installed npm modules available to Node.js
ENV NODE_PATH=/usr/local/lib/node_modules

ENTRYPOINT ["entrypoint.sh"]
