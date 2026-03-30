#!/bin/bash
# ============================================
# OpenClaw - Input Configuration Example
# ============================================
# Copy this file to inputs.sh and fill in your values:
#   cp secrets/inputs.example.sh secrets/inputs.sh
#
# Source before running Terraform:
#   source secrets/inputs.sh
#
# NEVER commit inputs.sh to version control

# ============================================
# REQUIRED: Hetzner Cloud API Token
# ============================================
# Generate at: https://console.hetzner.cloud/ -> Projects -> API Tokens
export HCLOUD_TOKEN="CHANGE_ME_your-hcloud-token-here"

# Terraform reads this as var.hcloud_token
export TF_VAR_hcloud_token="$HCLOUD_TOKEN"

# ============================================
# REQUIRED: SSH Configuration
# ============================================
# WARNING: Default value ["0.0.0.0/0"] allows SSH from ANY IP - INsecure!
# For production, change to your IP: ["YOUR_IP/32"]
# Or use '[]' for Tailscale-only access (requires enable_tailscale=true)
#
# To find your IP: curl -s ifconfig.me
# After confirming Tailscale SSH works, set this to '[]' and set SERVER_IP="openclaw-prod"
# below, then re-run: make apply
export TF_VAR_ssh_allowed_cidrs='["0.0.0.0/0"]'  # CHANGE THIS!

# Fingerprint of your existing Hetzner SSH key (avoids recreating shared keys)
# List yours: curl -s -H "Authorization: Bearer $HCLOUD_TOKEN" https://api.hetzner.cloud/v1/ssh_keys | jq '.ssh_keys[] | {name, fingerprint}'
export TF_VAR_ssh_key_fingerprint="CHANGE_ME_your-ssh-key-fingerprint"

# Path to SSH private key (default: ~/.ssh/id_rsa)
# Used by all deploy and helper scripts for SSH connections
# Set this if you use a different key name or location
# export SSH_KEY="$HOME/.ssh/id_rsa"

# ============================================
# SERVER CONNECTION
# ============================================
# When using Tailscale (ssh_allowed_cidrs='[]'), scripts can't reach the public
# IP. Set SERVER_IP to the Tailscale MagicDNS hostname — stable across rebuilds
# because cloud-init always registers the node as 'openclaw-prod'.
# Leave empty to auto-detect from terraform output (only works with public SSH).
# export SERVER_IP=""

# ============================================
# OPTIONAL: Claude Setup Token (for Claude Max/Pro subscription)
# ============================================
# Use your Claude subscription instead of paying for API credits.
# Generate with: claude setup-token
# Then run: make setup-auth
export CLAUDE_SETUP_TOKEN=""

# ============================================
# OPTIONAL: Tailscale VPN
# ============================================
# Enable Tailscale for private networking. When enabled:
# - Hetzner firewall opens UDP 41641 for WireGuard
# - Terraform generates a pre-auth key automatically (no manual console step)
# - 'make bootstrap' and 'make tailscale-enable' read the key from Terraform output
# - Set ssh_allowed_cidrs='[]' after confirming Tailscale works (make tailscale-enable does this atomically)
export TF_VAR_enable_tailscale=false

# Tailscale OAuth client credentials (required when enable_tailscale=true)
# Create at: https://login.tailscale.com/admin/settings/oauth
# Required scopes: auth_keys:write (to generate pre-auth keys)
# Optional scope:  acls:write (only needed if tailscale_enable_acl=true)
export TF_VAR_tailscale_oauth_client_id="CHANGE_ME_tskey-client-..."
export TF_VAR_tailscale_oauth_client_secret="CHANGE_ME_tskey-secret-..."

# ACL management via Terraform (default: false — manage ACL in Tailscale console instead)
# WARNING: setting this to true will REPLACE your entire tailnet ACL on next apply.
# export TF_VAR_tailscale_enable_acl=false

# TAILSCALE_AUTH_KEY is no longer set manually here.
# When enable_tailscale=true, 'make bootstrap' reads it automatically from:
#   terraform output -raw tailscale_auth_key
# To override (e.g. use an existing key): set TAILSCALE_AUTH_KEY in your shell before running make.

# ============================================
# Server Configuration (Optional Overrides)
# ============================================
# export TF_VAR_server_type="cx23"
# export TF_VAR_server_location="nbg1"
