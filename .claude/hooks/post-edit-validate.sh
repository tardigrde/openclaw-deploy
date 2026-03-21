#!/usr/bin/env bash
# Post-edit validation hook for Claude Code.
# Reads tool input JSON from stdin, runs the appropriate check based on file type.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
cd "$REPO_ROOT"

file=$(jq -r '.tool_input.file_path // ""' 2>/dev/null) || exit 0

[ -z "$file" ] && exit 0

# Normalize to repo-relative path
rel="${file#"$REPO_ROOT"/}"

case "$rel" in
  ansible/plays/*.yml | ansible/site.yml)
    echo "[hook] Ansible syntax check..."
    ANSIBLE_CONFIG=ansible/ansible.cfg \
      ansible-playbook --syntax-check -i localhost, ansible/site.yml
    ;;
  scripts/*.sh | scripts/lib/*.sh | scripts/addons/*.sh)
    echo "[hook] ShellCheck: $rel"
    shellcheck --severity=warning "$file"
    ;;
  openclaw.json)
    echo "[hook] Validating openclaw.json..."
    jq empty "$file" && echo "openclaw.json: valid JSON"
    ;;
esac
