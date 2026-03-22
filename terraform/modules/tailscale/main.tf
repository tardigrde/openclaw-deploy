# =============================================================================
# Tailscale Module
# =============================================================================
# Manages Tailscale tailnet configuration via the official Terraform provider.
#
# What this manages:
#   - tailscale_tailnet_key      : pre-auth key for bootstrapping the openclaw server
#   - tailscale_tailnet_settings : tailnet-wide settings (device approval, auto-updates)
#   - tailscale_dns_preferences  : MagicDNS DNS resolution
#   - tailscale_acl              : tailnet ACL policy (WARNING: replaces the entire ACL)
#
# What stays in Ansible (no Terraform resource exists):
#   - Tailscale install (curl install.sh)
#   - tailscale up / node registration
#   - UFW rule for UDP 41641 (guest firewall layer)
#   - tailscale serve config (serve.json deployed by Ansible on make deploy)
#
# Auth: provider uses OAuth client credentials, not an API key.
# Create an OAuth client at: https://login.tailscale.com/admin/settings/oauth
# Required scopes: auth_keys, acls, settings, dns
# Required tags:   tag:openclaw-vps (only — see note below)
#
# NOTE: The Terraform OAuth client must have exactly ONE tag (tag:openclaw-vps).
# Tailscale OAuth clients with 2+ tags require ALL tags simultaneously on every
# auth key request — so a multi-tag client cannot create single-tag keys.
# The GitHub Actions CI client (tag:ci-runner) must be a separate OAuth client
# with scope "Devices: Write" only. See docs/gitops-auto-deploy.md.
# =============================================================================

terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28"
    }
  }
}
# Provider is configured in the root module (terraform/envs/prod/main.tf)

# =============================================================================
# Auth Key
# =============================================================================
# Reusable pre-authorized key for the openclaw-vps node.
# Reusable: re-running bootstrap doesn't require a new key.
# Tags: tag:openclaw-vps must exist in tagOwners before it can be assigned.
# Expiry: 90 days - rotate via `terraform apply` when it expires.
# =============================================================================

resource "tailscale_tailnet_key" "openclaw" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000 # 90 days in seconds
  description   = "openclaw-${var.environment} bootstrap key"
  tags          = ["tag:openclaw-vps"]
}

# =============================================================================
# Tailnet Settings
# =============================================================================
# Tailnet-wide settings - these apply to your entire tailnet, not just this VPS.
# Requires OAuth scope: settings:write
# Note: devices_key_duration_days and users_role_allowed_to_join_external_tailnet
# require elevated permissions not available via OAuth clients - manage in console.
# =============================================================================

resource "tailscale_tailnet_settings" "main" {
  devices_approval_on     = false # auto-approve tagged nodes; set true to require manual approval
  devices_auto_updates_on = false
  network_flow_logging_on = false
  regional_routing_on     = false
  users_approval_on       = false
}

# =============================================================================
# DNS Preferences
# =============================================================================
# Enable MagicDNS so devices are reachable by hostname (e.g. openclaw-prod).
# Required for `make tailscale-enable` to switch SERVER_IP to "openclaw-prod".
# Requires OAuth scope: dns:write
# =============================================================================

resource "tailscale_dns_preferences" "main" {
  magic_dns = true
}

# =============================================================================
# ACL Policy
# =============================================================================
# WARNING: This resource replaces the *entire* tailnet ACL on every apply.
# If you manage ACL rules elsewhere (Tailscale console, HuJSON files), set
# enable_acl = false in the module call to skip this resource.
#
# Tag model:
#   tag:openclaw-vps  - the VPS running OpenClaw
#   tag:ci-runner     - GitHub Actions CI (Tailscale OAuth ephemeral nodes)
#
# Access rules (grants format):
#   - All users/devices -> anywhere (unrestricted, comment out to lock down)
#   - ci-runner -> openclaw-vps on SSH (22)
# =============================================================================

resource "tailscale_acl" "main" {
  count = var.enable_acl ? 1 : 0

  acl = jsonencode({
    tagOwners = {
      "tag:openclaw-vps" = []
      "tag:ci-runner"    = []
    }

    grants = [
      # Allow all connections (comment out to restrict to explicit rules below)
      {
        src = ["*"]
        dst = ["*"]
        ip  = ["*"]
      },
      # CI runner can SSH into openclaw-vps for Ansible deploys
      {
        src = ["tag:ci-runner"]
        dst = ["tag:openclaw-vps"]
        ip  = ["tcp:22"]
      },
    ]

    ssh = [
      # Tailnet members can SSH into their own devices
      {
        action = "check"
        src    = ["autogroup:member"]
        dst    = ["autogroup:self"]
        users  = ["autogroup:nonroot", "root"]
      },
    ]
  })
}
