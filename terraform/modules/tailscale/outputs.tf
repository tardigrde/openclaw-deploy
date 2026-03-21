output "auth_key" {
  description = "Tailscale pre-auth key for bootstrapping openclaw-server nodes. Consumed by Ansible via TAILSCALE_AUTH_KEY."
  value       = tailscale_tailnet_key.openclaw.key
  sensitive   = true
}
