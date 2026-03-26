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
# cosign is used at build time to verify the SOPS release signature — no hardcoded hash needed.
ARG SOPS_VERSION=3.12.2
COPY --from=gcr.io/projectsigstore/cosign:v3.0.5 /ko-app/cosign /usr/local/bin/cosign
COPY scripts/install-sops.sh /usr/local/bin/install-sops.sh
RUN bash /usr/local/bin/install-sops.sh "${SOPS_VERSION}"

# Install uv (Python package manager) — manages Python versions and project deps
ARG UV_VERSION=0.11.1
RUN curl -LsSf https://astral.sh/uv/${UV_VERSION}/install.sh | sh \
  && mv /root/.local/bin/uv /usr/local/bin/uv \
  && mv /root/.local/bin/uvx /usr/local/bin/uvx \
  && rm -rf /root/.local

# Pin versions for reproducible builds — bump explicitly when upgrading
ARG OPENCLAW_VERSION=2026.3.24
ARG CLAWHUB_VERSION=0.9.0
ARG SUMMARIZE_VERSION=0.12.0
ARG WS_VERSION=8.20.0
# Optional packages (e.g. acpx, claude-code) go in docker/install-optional.sh
COPY docker/install-optional.sh /tmp/install-optional.sh
RUN npm install -g \
    openclaw@${OPENCLAW_VERSION} \
    clawhub@${CLAWHUB_VERSION} \
    @steipete/summarize@${SUMMARIZE_VERSION} \
    ws@${WS_VERSION} \
  && bash /tmp/install-optional.sh \
  && npm cache clean --force \
  && mkdir -p /home/node/.openclaw/workspace /.clawhub \
  && chown -R node:node /home/node/.openclaw /.clawhub

# Copy skills manifest, workspace templates, agent templates, and entrypoint
COPY docker/skills-manifest.txt /opt/config/skills-manifest.txt
COPY docker/workspace-templates/ /opt/workspace-templates/
COPY docker/agent-workspace-templates/ /opt/agent-workspace-templates/
COPY docker/entrypoint.sh /usr/local/bin/entrypoint.sh
RUN chmod +x /usr/local/bin/entrypoint.sh

USER node

# Set git identity for agent commits
# Override via docker-compose build args (e.g. in docker-compose.override.yml)
ARG GIT_USER_NAME="OpenClaw"
ARG GIT_USER_EMAIL="openclaw@users.noreply.local"
RUN git config --global user.name "${GIT_USER_NAME}" \
 && git config --global user.email "${GIT_USER_EMAIL}"

# Make globally installed npm modules available to Node.js
ENV NODE_PATH=/usr/local/lib/node_modules

ENTRYPOINT ["entrypoint.sh"]
