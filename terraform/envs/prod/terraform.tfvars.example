# Non-secret Terraform configuration for the production environment.
# Secrets (hcloud_token, ssh_key_fingerprint) are passed via environment
# variables (locally: secrets/inputs.sh; CI: GitHub Secrets).

enable_tailscale = true

server_type     = "cx23"
server_location = "nbg1"

# SSH is open to everyone by default. To harden, either restrict to your IP
# or run `make tailscale-enable` to switch to Tailscale-only access.
ssh_allowed_cidrs = ["0.0.0.0/0"]
