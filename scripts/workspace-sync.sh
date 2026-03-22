#!/bin/bash
# =============================================================================
# OpenClaw Workspace Git Sync
# =============================================================================
# Commits and pushes the workspace to a private GitHub repo.
# Reads config from environment variables or sources ~/openclaw/.env.
# =============================================================================

set -euo pipefail

# If vars not already set, read from .env or decrypt .env.enc
if [[ -z "${GIT_WORKSPACE_REPO:-}" ]]; then
    ENV_FILE="${HOME}/openclaw/.env"
    ENV_ENC="${HOME}/openclaw/secrets/.env.enc"
    SOPS_BIN="$(command -v sops 2>/dev/null || echo "${HOME}/.local/bin/sops")"
    SOPS_AGE_KEY="${HOME}/.config/sops/age/keys.txt"

    if [[ -f "$ENV_FILE" ]]; then
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" =~ ^GIT_WORKSPACE_ ]] && export "${line?}" || true
        done < "$ENV_FILE"
    elif [[ -f "$ENV_ENC" && -x "$SOPS_BIN" && -f "$SOPS_AGE_KEY" ]]; then
        export SOPS_AGE_KEY_FILE="$SOPS_AGE_KEY"
        while IFS= read -r line; do
            [[ -z "$line" || "$line" =~ ^[[:space:]]*# ]] && continue
            [[ "$line" =~ ^GIT_WORKSPACE_ ]] && export "${line?}" || true
        done < <("$SOPS_BIN" -d --input-type dotenv --output-type dotenv "$ENV_ENC" 2>/dev/null)
    fi
fi

WORKSPACE_DIR="${OPENCLAW_WORKSPACE_DIR:-/home/openclaw/.openclaw/workspace}"

GIT_WORKSPACE_REPO="${GIT_WORKSPACE_REPO:-}"
GIT_WORKSPACE_BRANCH="${GIT_WORKSPACE_BRANCH:-auto}"
GIT_WORKSPACE_TOKEN="${GIT_WORKSPACE_TOKEN:-}"
GIT_WORKSPACE_EXTRA_DIRS="${GIT_WORKSPACE_EXTRA_DIRS:-}"

# -----------------------------------------------------------------------------
# Validate
# -----------------------------------------------------------------------------

if [[ -z "$GIT_WORKSPACE_REPO" ]]; then
    echo "[SKIP] GIT_WORKSPACE_REPO not set"
    exit 0
fi

if [[ -z "$GIT_WORKSPACE_TOKEN" ]]; then
    echo "[ERROR] GIT_WORKSPACE_TOKEN not set" >&2
    exit 1
fi

if [[ ! -d "$WORKSPACE_DIR" ]]; then
    echo "[SKIP] Workspace directory $WORKSPACE_DIR does not exist"
    exit 0
fi

# -----------------------------------------------------------------------------
# Git setup
# -----------------------------------------------------------------------------

REMOTE_URL="https://github.com/${GIT_WORKSPACE_REPO}.git"

# Store credentials in a temp file (mode 600) rather than embedding in the URL.
# This prevents the token from appearing in .git/config or ps aux.
_CRED_FILE=$(mktemp)
chmod 600 "$_CRED_FILE"
printf 'https://token:%s@github.com\n' "$GIT_WORKSPACE_TOKEN" > "$_CRED_FILE"
trap 'rm -f "$_CRED_FILE"' EXIT
export GIT_CONFIG_COUNT=1
export GIT_CONFIG_KEY_0="credential.helper"
export GIT_CONFIG_VALUE_0="store --file $_CRED_FILE"

echo "=== OpenClaw Workspace Sync ==="
echo "Repo: $GIT_WORKSPACE_REPO"
echo "Branch: $GIT_WORKSPACE_BRANCH"
echo ""

cd "$WORKSPACE_DIR"

# Fix ownership if .git has root-owned files (e.g. from accidental sudo run)
if [[ -d ".git" ]] && find .git -user root -print -quit | grep -q .; then
    echo "[...] Fixing .git ownership (was root, correcting to $(id -u):$(id -g))"
    chown -R "$(id -u):$(id -g)" .git 2>/dev/null || {
        echo "[ERROR] Cannot fix .git ownership — run: sudo chown -R $(id -u):$(id -g) $WORKSPACE_DIR/.git" >&2
        exit 1
    }
fi

if [[ ! -d ".git" ]]; then
    echo "[...] Initializing git repository..."
    git init -b "$GIT_WORKSPACE_BRANCH" --quiet
fi

if git remote get-url origin &>/dev/null; then
    git remote set-url origin "$REMOTE_URL"
else
    git remote add origin "$REMOTE_URL"
fi

git config user.name "OpenClaw Bot"
git config user.email "openclaw@noreply.local"

CURRENT_BRANCH=$(git branch --show-current 2>/dev/null || echo "")
if [[ -n "$CURRENT_BRANCH" && "$CURRENT_BRANCH" != "$GIT_WORKSPACE_BRANCH" ]]; then
    git branch -m "$CURRENT_BRANCH" "$GIT_WORKSPACE_BRANCH" 2>/dev/null || true
fi

# -----------------------------------------------------------------------------
# Commit and push
# -----------------------------------------------------------------------------

echo "[...] Checking for changes..."

# Sync any extra directories into the workspace before staging
if [[ -n "$GIT_WORKSPACE_EXTRA_DIRS" ]]; then
    IFS=':' read -ra _EXTRA_DIRS <<< "$GIT_WORKSPACE_EXTRA_DIRS"
    for _extra in "${_EXTRA_DIRS[@]}"; do
        _dest="$WORKSPACE_DIR/$(basename "$_extra")"
        echo "[...] Syncing extra dir: $_extra"
        rsync -a --delete "$_extra/" "$_dest/"
    done
fi

git add -A

if git diff --cached --quiet; then
    echo "[SKIP] No changes to sync"
    echo "=== Sync Complete ==="
    exit 0
fi

TIMESTAMP=$(date +"%Y-%m-%d %H:%M:%S")
FILE_COUNT=$(git diff --cached --numstat | wc -l | tr -d ' ')

echo "[...] Committing $FILE_COUNT changed file(s)..."
git commit -m "workspace sync $TIMESTAMP" --quiet

echo "[...] Pushing to $GIT_WORKSPACE_REPO ($GIT_WORKSPACE_BRANCH)..."

if git ls-remote --exit-code origin "$GIT_WORKSPACE_BRANCH" &>/dev/null; then
    git pull origin "$GIT_WORKSPACE_BRANCH" --rebase --allow-unrelated-histories --quiet 2>/dev/null || true
fi

git push -u origin "$GIT_WORKSPACE_BRANCH" --quiet 2>&1
echo "[OK] Workspace synced successfully"
echo "=== Sync Complete ==="
