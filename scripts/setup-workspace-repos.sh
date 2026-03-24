#!/bin/bash
# =============================================================================
# Workspace Repos Setup
# =============================================================================
# Clones all repos used in this OpenClaw workspace into workspace/repos/.
# Idempotent — skips repos that already exist. Uses gh auth for private repos.
#
# Usage:
#   ./scripts/setup-workspace-repos.sh          # from the IaC repo root
#   make workspace-repos                        # via Makefile
#
# Prerequisites:
#   - gh auth login (for private repo access)
#   - workspace/repos/ directory exists (created by bootstrap)
# =============================================================================

set -euo pipefail

WORKSPACE="${OPENCLAW_WORKSPACE:-$HOME/.openclaw/workspace}"
REPOS_DIR="$WORKSPACE/repos"

# GitHub org/user prefix
GH_ORG="tardigrde"

# All repos used in this workspace
# Format: "repo-name  description"
REPOS=(
    "openclaw-deploy          upstream IaC repo (open source)"
    "openclaw-prod            private deployment fork"
    "family-finance           household finance tool (Python)"
    "ingatlan-scraper         Budapest house hunting scraper"
    "openclaw-dropbox-plugin  Dropbox integration plugin"
)

# -----------------------------------------------------------------------------
echo "=== Workspace Repos Setup ==="
echo "Target: $REPOS_DIR"
echo ""

# Ensure repos directory exists
mkdir -p "$REPOS_DIR"

CLONED=0
SKIPPED=0
FAILED=0

for entry in "${REPOS[@]}"; do
    # Parse "repo-name  description"
    REPO=$(echo "$entry" | awk '{print $1}')
    DESC=$(echo "$entry" | cut -d' ' -f3-)
    TARGET="$REPOS_DIR/$REPO"

    if [[ -d "$TARGET/.git" ]]; then
        echo "[SKIP] $REPO — already cloned"
        SKIPPED=$((SKIPPED + 1))
    else
        echo "[...]  Cloning $REPO ($DESC)..."
        if gh repo clone "$GH_ORG/$REPO" "$TARGET" -- --quiet 2>/dev/null; then
            echo "[OK]   $REPO"
            CLONED=$((CLONED + 1))
        else
            echo "[FAIL] $REPO — could not clone (check gh auth and repo access)"
            FAILED=$((FAILED + 1))
        fi
    fi
done

echo ""
echo "=== Summary ==="
echo "Cloned: $CLONED  |  Skipped: $SKIPPED  |  Failed: $FAILED"
echo "Repos in: $REPOS_DIR"
ls -1 "$REPOS_DIR" 2>/dev/null || echo "(empty)"
echo ""
echo "=== Done ==="
