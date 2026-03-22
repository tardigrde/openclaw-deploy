#!/usr/bin/env bash
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$REPO_ROOT/openclaw.json"

# -----------------------------------------------------------------------------
# 1. Validate config JSON
# -----------------------------------------------------------------------------

if [[ ! -f "$CONFIG" ]]; then
  echo "SKIP: $CONFIG not found (copy openclaw.example.json to openclaw.json)"
  echo ""
else
  echo "Validating $CONFIG ..."

  if ! jq empty "$CONFIG" 2>/dev/null; then
    echo "ERROR: $CONFIG is not valid JSON" >&2
    exit 1
  fi

  PATTERNS='sk-ant-|sk-proj-|bot[0-9]|bsc_|xai-|gsk_'
  if grep -qE "$PATTERNS" "$CONFIG"; then
    echo "ERROR: Raw API key pattern detected in $CONFIG" >&2
    echo "Use \${ENV_VAR} references instead of plaintext keys." >&2
    grep -nE "$PATTERNS" "$CONFIG" >&2
    exit 1
  fi

  echo "✓ Config validation passed"
  echo ""
fi

# -----------------------------------------------------------------------------
# 2. Scan tracked files for secrets
# -----------------------------------------------------------------------------

echo "Scanning tracked files for secrets ..."

FOUND=0

SECRET_PATTERNS=(
  'sk-ant-[A-Za-z0-9_-]{20,}'
  'sk-proj-[A-Za-z0-9_-]{20,}'
  'bot[0-9]{8,}:[A-Za-z0-9_-]{30,}'
  'bsc_[A-Za-z0-9]{20,}'
  'xai-[A-Za-z0-9]{20,}'
  'gsk_[A-Za-z0-9]{20,}'
  '[A-Za-z0-9+/]{40,}={0,2}'
  'Bearer [A-Za-z0-9._-]{20,}'
)

FILES=$(cd "$REPO_ROOT" && git ls-files | grep -v '\.env\.example$' | grep -v '\.env\.enc$' | grep -v '\.md$' | grep -v '^go\.sum$' || true)

if [[ -z "$FILES" ]]; then
  echo "✓ No secrets detected in tracked files"
  exit 0
fi

for pattern in "${SECRET_PATTERNS[@]}"; do
  while IFS= read -r file; do
    [[ -z "$file" ]] && continue
    FILEPATH="$REPO_ROOT/$file"
    [[ -f "$FILEPATH" ]] || continue
    if grep -qE "$pattern" "$FILEPATH" 2>/dev/null; then
      # Filter out SHA256 checksums and age public keys (not secrets)
      MATCHES=$(grep -nE "$pattern" "$FILEPATH" | grep -viE 'SHA256=|sha256sum|age1[a-z0-9]{50,}|version:\s+[0-9a-f]{40}' || true)
      if [[ -n "$MATCHES" ]]; then
        echo "SECRET DETECTED in $file:"
        echo "$MATCHES"
        FOUND=1
      fi
    fi
  done <<< "$FILES"
done

if [[ "$FOUND" -eq 1 ]]; then
  echo ""
  echo "ERROR: Secrets detected in tracked files. Remove them before committing." >&2
  exit 1
fi

echo "✓ No secrets detected in tracked files"
