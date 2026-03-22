output "auth_key" {
  description = "Tailscale pre-auth key for bootstrapping openclaw-server nodes. Consumed by Ansible via TAILSCALE_AUTH_KEY."
  value       = tailscale_tailnet_key.openclaw.key
  sensitive   = true
}

output "ci_runner_auth_key" {
  description = "Tailscale pre-auth key for GitHub Actions CI nodes (ephemeral, tag:ci-runner). Store as GitHub Secret TAILSCALE_AUTH_KEY."
  value       = tailscale_tailnet_key.ci_runner.key
  sensitive   = true
}
