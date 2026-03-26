#!/usr/bin/env bash
set -euo pipefail

MANIFEST="/opt/config/skills-manifest.txt"
WORKDIR="/home/node/.openclaw/workspace"

###############################################################################
# Seed workspace templates (no-clobber — won't overwrite existing files)
###############################################################################
TEMPLATES="/opt/workspace-templates"
if [[ -d "$TEMPLATES" ]]; then
  echo "[entrypoint] Seeding workspace templates ..."
  cp -rn "$TEMPLATES"/. "$WORKDIR"/
fi

###############################################################################
# Seed agent workspace templates into workspace/agents/ (no-clobber)
###############################################################################
AGENT_TEMPLATES="/opt/agent-workspace-templates"
AGENTS_DIR="$WORKDIR/agents"
if [[ -d "$AGENT_TEMPLATES" ]] && [[ -n "$(ls -A "$AGENT_TEMPLATES" 2>/dev/null)" ]]; then
  echo "[entrypoint] Seeding agent workspace templates ..."
  mkdir -p "$AGENTS_DIR"
  cp -rn "$AGENT_TEMPLATES"/. "$AGENTS_DIR"/
fi

###############################################################################
# Install ClawHub skills from the manifest (if present)
###############################################################################
if [[ -f "$MANIFEST" ]]; then
  echo "[entrypoint] Installing ClawHub skills from manifest ..."
  while IFS= read -r line; do
    # Skip blank lines and comments
    line="${line%%#*}"
    line="$(echo "$line" | xargs)"
    [[ -z "$line" ]] && continue

    # Skip if already installed
    if [[ -d "$WORKDIR/skills/$line" ]]; then
      echo "[entrypoint]   ✓ $line (already installed)"
      continue
    fi

    echo "[entrypoint]   → installing $line"
    clawhub install "$line" --workdir "$WORKDIR" --force || {
      echo "[entrypoint] WARNING: Failed to install $line — continuing"
    }
  done < "$MANIFEST"
  echo "[entrypoint] Skill installation complete."
else
  echo "[entrypoint] No skills manifest found — skipping skill install."
fi

###############################################################################
# Install lossless-claw plugin (opt-out via INSTALL_LOSSLESS_CLAW=0)
###############################################################################
if [[ "${INSTALL_LOSSLESS_CLAW:-1}" != "0" ]]; then
  echo "[entrypoint] Installing lossless-claw plugin ..."
  openclaw plugins install @martian-engineering/lossless-claw@0.5.2 2>&1 || {
    echo "[entrypoint] WARNING: Failed to install lossless-claw — continuing"
  }
else
  echo "[entrypoint] Skipping lossless-claw (INSTALL_LOSSLESS_CLAW=0)"
fi

###############################################################################
# Run optional local extensions (private deployments — never in openclaw-deploy)
# Mount docker/entrypoint.local.sh into /usr/local/bin/entrypoint.local.sh
###############################################################################
if [[ -f /usr/local/bin/entrypoint.local.sh ]]; then
  echo "[entrypoint] Running local extensions ..."
  # shellcheck source=/dev/null
  source /usr/local/bin/entrypoint.local.sh
fi

###############################################################################
# Hand off to the real command (CMD from docker-compose)
###############################################################################
exec "$@"
