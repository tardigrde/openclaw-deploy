# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in this project, please report it responsibly:

1. **Do NOT** open a public GitHub issue
2. Use [GitHub Security Advisories](../../security/advisories/new) to report vulnerabilities privately
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Potential impact
   - Suggested fix (if you have one)

We aim to respond to security reports within 48 hours and will work with you to understand and address the issue.

## Supported Versions

| Version | Supported          |
| ------- | ------------------ |
| main    | :white_check_mark: |
| < 1.0   | :x:                |

## Security Considerations

### Infrastructure Security

This project deploys cloud infrastructure. Please be aware of:

1. **API Credentials**
   - Never commit `secrets/inputs.sh` or `secrets/.env` — both are gitignored
   - See [docs/secrets.md](docs/secrets.md) for the full secrets model (two-file layout, SOPS encryption, how secrets reach the VPS)
   - Rotate API tokens regularly
   - Use separate tokens for different environments

2. **SSH Access**
   - Default opens SSH (port 22) to `0.0.0.0/0` — restrict before production
   - **Minimum:** restrict to your IP via `TF_VAR_ssh_allowed_cidrs`
   - **Best:** enable Tailscale (see section 3) and set `TF_VAR_ssh_allowed_cidrs='[]'` so SSH is invisible to the public internet entirely
   - Hetzner Ubuntu images disable password authentication by default; the VPS uses key-only auth
   - Protect your SSH private key — it is the only credential that grants access

3. **Tailscale VPN (Recommended)**

   Tailscale builds a WireGuard-encrypted mesh network between your devices and the VPS. When enabled, the server gets a private `100.x.x.x` address that is only reachable from devices authenticated to your tailnet.

   **What this protects against:**
   - SSH scanners and brute-force bots — they see a closed port on the public IP
   - Network-level eavesdropping — all traffic is end-to-end WireGuard encrypted, regardless of the network you're connecting from (hotel WiFi, mobile data, etc.)
   - Accidental gateway exposure — Tailscale Serve makes the OpenClaw dashboard accessible only to authenticated tailnet members, not the public internet

   **What this does not protect against:**
   - A compromised device that is already enrolled in your tailnet
   - A stolen or leaked Tailscale auth key (mitigate with expiring keys and MFA)
   - Vulnerabilities in OpenClaw or its dependencies

   Tailscale is installed automatically on first boot when `TF_VAR_enable_tailscale=true` is set. See [Firewall / Network Access](../README.md#firewall--network-access) in the README for the step-by-step setup.

4. **Firewall Rules**
   - Inbound by default: SSH (22/tcp) only — no HTTP/HTTPS exposed at the Hetzner level
   - With Tailscale: additionally opens UDP 41641 for WireGuard; SSH port can then be closed entirely
   - Gateway binds to `127.0.0.1` (localhost only) and is never directly reachable from the internet
   - Review `terraform/modules/hetzner-vps/main.tf` for the full rule set

5. **Cloud-Init Scripts**
   - Review `terraform/modules/hetzner-vps/cloud-init/user-data.yml.tpl` before deploying
   - Runs with root privileges on first boot
   - Modifying this can affect server security
   - Tailscale installation uses official packages from the Tailscale repository

6. **State Files**
   - Terraform state contains sensitive data — never commit `.tfstate` files
   - Default backend is local; GCS remote state (with versioning and encryption at rest) is recommended for teams — see [docs/remote-state.md](docs/remote-state.md)

### Application Security

7. **OpenClaw Gateway**
   - Set strong `OPENCLAW_GATEWAY_TOKEN` in `secrets/.env`
   - Use SSH tunneling to access gateway (don't expose publicly)
   - Keep OpenClaw updated to latest version

8. **API Keys**
   - Claude/Anthropic API keys grant access to your account
   - Monitor usage and set spending limits
   - Use setup-token (subscription) instead of API keys when possible
   - Telegram bot tokens should be kept secret

### Tailscale Security

9. **Tailscale Auth Keys**
   - Generate auth keys at [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys)
   - Use reusable, pre-authorized keys for easier deployment
   - Set expiration (90 days recommended) and rotate regularly
   - Never commit auth keys to version control
   - Passed to Ansible via `TAILSCALE_AUTH_KEY` env var (set in `secrets/inputs.sh`)
   - Enable MFA on your Tailscale account

### Cost Security

10. **Resource Limits**
    - Set up billing alerts in Hetzner Console
    - Start with small server types (cx23) for testing
    - Monitor resource usage regularly
    - Destroy test deployments when done (`make destroy`)

## Best Practices

### For Maintainers

- Review all PRs for security implications
- Run automated security scanning (tfsec, checkov)
- Keep dependencies updated
- Document security-relevant changes in release notes

### For Users

- Read the code before deploying to your infrastructure
- Start with a test deployment in a separate Hetzner project
- Use separate API credentials for testing vs production
- Enable two-factor authentication on your Hetzner account
- Regularly update to the latest version

## Known Security Considerations

### By Design

- Cloud-init runs with root privileges (standard for server provisioning)
- SSH access is initially broad (users should narrow this per the README)
- Gateway uses API tokens for authentication (consider adding TLS)
- **`journalctl *` sudo rule** — the app user (`openclaw`) can read all systemd journal entries, including auth logs and anything containers write to stderr. This is intentional to support container log streaming from Ansible/Makefile commands. Side effect: API keys accidentally printed to stderr by containers are readable by the app user. Mitigate by ensuring containers do not log secrets.
- **Tailscale installed via `curl | sh`** — bootstrapping runs `curl -fsSL https://tailscale.com/install.sh | sh` as root without checksum verification. This is the upstream-recommended install path. Risk: a supply chain compromise of tailscale.com at bootstrap time would result in RCE. Mitigate by reviewing the script before running or switching to the APT package method.
- **Unencrypted intra-container WebSocket** — `OPENCLAW_ALLOW_INSECURE_PRIVATE_WS=1` permits plain `ws://` connections between mission-control and the gateway over the Docker bridge network. Any process on the host that can reach the bridge (e.g., another container) can observe tokens in transit. Acceptable for a single-tenant VPS where no untrusted containers share the host.

### Out of Scope

This project does NOT provide:
- DDoS protection (use Hetzner's DDoS protection or Cloudflare)
- Automated security patching (you must update OpenClaw manually — see [docs/versions.md](docs/versions.md))

The following are **already included** (not out of scope):
- Intrusion detection — fail2ban is active with `maxretry=3`, `bantime=1h` (configured via cloud-init)
- Secrets encryption at rest — SOPS/age encryption for `.env` (see [docs/secrets.md](docs/secrets.md))
- Automatic security updates — `unattended-upgrades` is installed and enabled via cloud-init

## Security Updates

Security updates will be released as patch versions and announced via:
- GitHub Security Advisories
- Release notes
- README badges (if applicable)

## Responsible Disclosure

We follow responsible disclosure practices:
- 90-day disclosure timeline for vulnerabilities
- Coordinated public disclosure after fix is available
- Credit given to reporters (if desired)
- CVE assignment for significant vulnerabilities (if applicable)

## Acknowledgments

We appreciate the security research community and all contributors who help keep this project secure.
