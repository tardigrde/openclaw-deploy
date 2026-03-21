#!/bin/bash
# =============================================================================
# OpenClaw Shared Library
# =============================================================================
# Common functions used by deployment and operational scripts.
# Source this file in your scripts: source "$(dirname "$0")/lib/vps.sh"
# =============================================================================

set -euo pipefail

# -----------------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------------

VPS_USER="openclaw"
SSH_KEY="${SSH_KEY:-$HOME/.ssh/id_rsa}"
TERRAFORM_DIR="terraform/envs/prod"

# Colors
export GREEN='\033[0;32m'
export YELLOW='\033[1;33m'
export RED='\033[0;31m'
export BLUE='\033[0;34m'
export BOLD='\033[1m'
export DIM='\033[2m'
export NC='\033[0m'

# -----------------------------------------------------------------------------
# SSH Options (use directly in commands)
# -----------------------------------------------------------------------------
# Usage: ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$SSH_KEY" user@host "cmd"
#        scp -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$SSH_KEY" local user@host:remote
# -----------------------------------------------------------------------------

# -----------------------------------------------------------------------------
# Get VPS IP
# -----------------------------------------------------------------------------
# Detects the VPS IP from:
#   1. First positional argument
#   2. $SERVER_IP environment variable (set from secrets/inputs.sh)
#   3. Terraform output (if available and initialized)
# -----------------------------------------------------------------------------

get_vps_ip() {
    local ip="${1:-}"

    # Priority 1: Positional argument
    if [[ -n "$ip" ]]; then
        echo "$ip"
        return 0
    fi

    # Priority 2: Environment variable (from secrets/inputs.sh)
    if [[ -n "${SERVER_IP:-}" ]]; then
        echo "$SERVER_IP"
        return 0
    fi

    # Priority 3: Terraform output
    if command -v terraform &> /dev/null && [[ -d "$TERRAFORM_DIR/.terraform" ]]; then
        local tf_ip
        tf_ip=$(cd "$TERRAFORM_DIR" && terraform output -raw server_ip 2>/dev/null) || true
        if [[ -n "$tf_ip" ]]; then
            echo "$tf_ip"
            return 0
        fi
    fi

    echo "Error: Could not determine VPS IP." >&2
    echo "Set SERVER_IP in secrets/inputs.sh or pass as argument." >&2
    return 1
}

# -----------------------------------------------------------------------------
# SSH to VPS
# -----------------------------------------------------------------------------
# Usage: ssh_to_vps [IP] "command"
# If command provided, executes remotely. Otherwise opens interactive shell.
# -----------------------------------------------------------------------------

ssh_to_vps() {
    local vps_ip
    vps_ip=$(get_vps_ip "${1:-}") && shift || return 1

    ssh -o StrictHostKeyChecking=accept-new -o ConnectTimeout=10 -i "$SSH_KEY" "$VPS_USER@$vps_ip" "$@"
}
