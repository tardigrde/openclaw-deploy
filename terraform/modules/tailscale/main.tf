# =============================================================================
# Tailscale Module
# =============================================================================
# Manages Tailscale tailnet configuration via the official Terraform provider.
#
# What this manages:
#   - tailscale_tailnet_key  : pre-auth key for bootstrapping the openclaw server
#   - tailscale_acl          : tailnet ACL policy (WARNING: replaces the entire ACL)
#
# What stays in Ansible (no Terraform resource exists):
#   - tailscale install (curl install.sh)
#   - tailscale up / node registration
#   - UFW rule for UDP 41641 (guest firewall layer)
#
# Auth: provider uses OAuth client credentials, not an API key.
# Create an OAuth client at: https://login.tailscale.com/admin/settings/oauth
# Required scopes: auth_keys:write (for key generation), acls:write (for ACL).
# =============================================================================

terraform {
  required_providers {
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.17"
    }
  }
}
# Provider is configured in the root module (terraform/envs/prod/main.tf)

# =============================================================================
# Auth Key
# =============================================================================
# Reusable pre-authorized key for the openclaw-server node.
# Reusable: re-running bootstrap doesn't require a new key.
# Tags: enables tag-based ACL rules for the registered device.
# Expiry: 90 days — rotate via `terraform apply` when it expires.
# =============================================================================

resource "tailscale_tailnet_key" "openclaw" {
  reusable      = true
  ephemeral     = false
  preauthorized = true
  expiry        = 7776000 # 90 days in seconds
  description   = "openclaw-${var.environment} bootstrap key (managed by Terraform)"
  tags          = ["tag:openclaw-server"]
}

# =============================================================================
# ACL Policy
# =============================================================================
# WARNING: This resource replaces the *entire* tailnet ACL on every apply.
# If you manage ACL rules elsewhere (Tailscale console, HuJSON files), set
# enable_acl = false in the module call to skip this resource.
#
# Tag model:
#   tag:openclaw-server  — the VPS running OpenClaw
#   tag:ci-runner        — GitHub Actions CI (Tailscale OAuth ephemeral nodes)
#
# Access rules:
#   - Tailnet members (you) → openclaw-server on SSH (22) and gateway (18789)
#   - ci-runner → openclaw-server SSH only (for Ansible deploys)
#   - openclaw-server → anywhere (for package installs, API calls, etc.)
# =============================================================================

resource "tailscale_acl" "main" {
  count = var.enable_acl ? 1 : 0

  acl = jsonencode({
    tagOwners = {
      "tag:openclaw-server" = ["autogroup:admin"]
      "tag:ci-runner"       = ["autogroup:admin"]
    }

    acls = [
      # Tailnet members can reach the openclaw server on SSH and gateway port
      {
        action = "accept"
        src    = ["autogroup:member"]
        dst    = ["tag:openclaw-server:22", "tag:openclaw-server:18789"]
      },
      # CI runner can SSH into openclaw server for Ansible deploys
      {
        action = "accept"
        src    = ["tag:ci-runner"]
        dst    = ["tag:openclaw-server:22"]
      },
      # openclaw server has full outbound access (package installs, API calls)
      {
        action = "accept"
        src    = ["tag:openclaw-server"]
        dst    = ["*:*"]
      },
    ]

    ssh = [
      # Tailnet members can SSH into openclaw-server as the app user or root
      {
        action = "accept"
        src    = ["autogroup:admin"]
        dst    = ["tag:openclaw-server"]
        users  = ["openclaw", "root"]
      },
    ]
  })
}
