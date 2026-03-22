# ============================================
# Production Environment - Terraform Configuration
# ============================================
# This configuration creates the production OpenClaw VPS on Hetzner Cloud

terraform {
  required_version = "~> 1.7"

  required_providers {
    hcloud = {
      source  = "hetznercloud/hcloud"
      version = "~> 1.45"
    }
    tailscale = {
      source  = "tailscale/tailscale"
      version = "~> 0.28"
    }
  }

  # Backend is configured in backend.tf (gitignored).
  # Copy backend.tf.example → backend.tf to get started (defaults to local state).
}

# ============================================
# Provider
# ============================================

provider "hcloud" {
  token = var.hcloud_token
}

provider "tailscale" {
  oauth_client_id     = var.tailscale_oauth_client_id
  oauth_client_secret = var.tailscale_oauth_client_secret
}

# ============================================
# VPS Module
# ============================================

module "vps" {
  source = "../../modules/hetzner-vps"

  project_name        = var.project_name
  environment         = "prod"
  ssh_key_fingerprint = var.ssh_key_fingerprint
  ssh_allowed_cidrs   = var.ssh_allowed_cidrs
  server_type         = var.server_type
  server_location     = var.server_location
  app_user            = var.app_user
  app_directory       = var.app_directory

  # Security configuration
  enable_tailscale = var.enable_tailscale
}

# ============================================
# Tailscale Module (only when Tailscale is enabled)
# ============================================

module "tailscale" {
  count  = var.enable_tailscale ? 1 : 0
  source = "../../modules/tailscale"

  environment = "prod"
  enable_acl  = var.tailscale_enable_acl
}

# ============================================
# Outputs
# ============================================

output "server_ip" {
  description = "Public IPv4 address of the OpenClaw server"
  value       = module.vps.server_ipv4
}

output "server_ipv6" {
  description = "Public IPv6 address of the OpenClaw server"
  value       = module.vps.server_ipv6
}

output "server_id" {
  description = "Hetzner Cloud server ID"
  value       = module.vps.server_id
}

output "server_status" {
  description = "Current status of the server"
  value       = module.vps.server_status
}

output "ssh_command" {
  description = "SSH command to connect as the application user"
  value       = module.vps.ssh_command
}

output "ssh_command_root" {
  description = "SSH command to connect as root"
  value       = module.vps.ssh_command_root
}

output "ssh_key_id" {
  description = "Hetzner Cloud SSH key ID"
  value       = module.vps.ssh_key_id
}

output "firewall_id" {
  description = "Hetzner Cloud firewall ID"
  value       = module.vps.firewall_id
}

output "tailscale_enabled" {
  description = "Whether Tailscale VPN is enabled"
  value       = module.vps.tailscale_enabled
}

output "tailscale_auth_key" {
  description = "Tailscale pre-auth key for bootstrapping. Consumed automatically by 'make bootstrap' and 'make tailscale-enable' when TAILSCALE_AUTH_KEY is not set in the environment."
  value       = var.enable_tailscale ? module.tailscale[0].auth_key : null
  sensitive   = true
}

output "tailscale_ci_runner_auth_key" {
  description = "Tailscale pre-auth key for GitHub Actions CI (ephemeral, tag:ci-runner). Store as GitHub Secret TAILSCALE_AUTH_KEY."
  value       = var.enable_tailscale ? module.tailscale[0].ci_runner_auth_key : null
  sensitive   = true
}
