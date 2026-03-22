# OpenClaw on Hetzner VPS

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)
[![Terraform](https://img.shields.io/badge/Terraform-1.5+-purple.svg)](https://www.terraform.io/)

Infrastructure-as-code for deploying [OpenClaw](https://openclaw.ai) on a Hetzner Cloud VPS inside Docker. Includes VPS provisioning, firewall configuration, cloud-init automation, and Ansible-driven deployment.

For information about OpenClaw itself, see the [OpenClaw documentation](https://docs.openclaw.ai/).

## Overview

- Terraform provisions the VPS and firewall
- Ansible handles all deployment tasks — idempotent, dry-run capable, single command for every scenario (runs locally only, never in CI)
- Docker Compose runs OpenClaw gateway + headless Chromium on the VPS
- All day-to-day operations go through `make`

## Prerequisites

1. **Terraform** >= 1.5 ([install](https://developer.hashicorp.com/terraform/install))
2. **Ansible** ([install](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html))
3. **age** and **sops** — required for secret encryption (`make secrets-encrypt`). Install via your package manager or [age releases](https://github.com/FiloSottile/age/releases) / [sops releases](https://github.com/getsops/sops/releases).
4. **jq** — required for `make validate`. Install via your package manager.
5. **Hetzner Cloud account** with API token ([console](https://console.hetzner.cloud/))
6. **SSH key** uploaded to Hetzner Cloud. Default path: `~/.ssh/id_rsa`. Override with `SSH_KEY` env var.
7. *(Optional)* **Remote Terraform state** — the default is local (no setup needed). For GCS or other remote backends, see [docs/remote-state.md](docs/remote-state.md).

## Quick Start

### 1. Clone

```bash
git clone https://github.com/tardigrde/openclaw-deploy.git
cd openclaw-deploy
```

### 2. Configure infrastructure secrets

```bash
cp secrets/inputs.example.sh secrets/inputs.sh
vim secrets/inputs.sh
```

Required: `HCLOUD_TOKEN`, `TF_VAR_ssh_key_fingerprint` (from [Hetzner Console](https://console.hetzner.cloud/) → Security → SSH Keys). See [docs/secrets.md](docs/secrets.md) for the full variable reference and Tailscale-specific notes.

### 3. Configure OpenClaw

```bash
cp openclaw.example.json openclaw.json
vim openclaw.json
```

Customize: Telegram IDs, timezone, AI models. See the official [OpenClaw configuration docs](https://docs.openclaw.ai/gateway/configuration-reference) for details on every option.

> **Tailscale users:** Skip the `allowedOrigins` Tailscale hostname for now — you won't know it until after bootstrap. You'll fill it in at the Tailscale setup step.

### 4. Configure Terraform backend

```bash
cp terraform/envs/prod/backend.tf.example terraform/envs/prod/backend.tf
```

The default (`backend "local"`) requires no setup. To use GCS remote state instead, edit `backend.tf` — see [Remote State Backend](#remote-state-backend).

### 5. Provision the VPS

```bash
source secrets/inputs.sh
make init
make plan
make apply
```

### 6. Configure container secrets

```bash
cp secrets/.env.example secrets/.env
vim secrets/.env
```

Required: `OPENCLAW_GATEWAY_TOKEN`, `ANTHROPIC_API_KEY` (or leave empty for subscription auth), `TELEGRAM_BOT_TOKEN`. See [docs/secrets.md](docs/secrets.md) for the full variable reference.

### 7. (Optional) Encrypt secrets at rest with SOPS

Complete step 6 first — `make secrets-encrypt` reads `secrets/.env`.

```bash
make secrets-generate-key   # generates secrets/age-key.txt and prints the public key
# Edit .sops.yaml — paste the age public key printed above into the `age:` field
make secrets-encrypt        # encrypts secrets/.env → secrets/.env.enc
```

Plain `.env` works for local use. SOPS is **required** for the [GitOps auto-deploy workflow](docs/gitops-auto-deploy.md). See [docs/secrets.md § SOPS](docs/secrets.md#sops-encryption-optional-for-local-required-for-ci) for the full workflow.

> **Adding extra services?** If you plan to run additional services (e.g. Mission Control), copy `docker-compose.override.example.yml → docker-compose.override.yml` before the next step — it cannot be merged in after bootstrap without re-running it. See [Override System](#override-system).
>
> ```bash
> cp docker-compose.override.example.yml docker-compose.override.yml
> vim docker-compose.override.yml
> ```

### 8. Bootstrap OpenClaw

```bash
source secrets/inputs.sh
make bootstrap
```

Creates directories, builds Docker images, pushes config, and starts containers — everything in one command.

> **Claude subscription auth:** If you left `ANTHROPIC_API_KEY` empty, run `make setup-auth` after bootstrap to link your Claude subscription.

### 9. Verify

```bash
make status   # all containers should show "healthy" or "running"
make logs     # look for "[entrypoint] Skill installation complete" and "Gateway listening"
make tunnel   # opens SSH tunnel: localhost:18789 → VPS:18789
```

Open `http://localhost:18789` and paste your `OPENCLAW_GATEWAY_TOKEN` to authenticate.

**Success looks like:** Gateway UI loads, token is accepted, you can start a conversation.

**Common failures:**
- `make status` shows container restarting → check `make logs` for missing env vars (most likely `OPENCLAW_GATEWAY_TOKEN` not set in `.env`)
- `make tunnel` hangs → SSH key or `SERVER_IP` issue; verify with `make ssh`
- Gateway UI shows "Unauthorized" → wrong `OPENCLAW_GATEWAY_TOKEN`

## Architecture

```text
┌──────────────────────────────┐
│          Your Laptop          │
│                              │
│  Terraform  Ansible  make    │
└──────────────┬───────────────┘
               │ SSH (or Tailscale)
               v
┌──────────────────────────────┐
│      Hetzner Cloud VPS       │
│                              │
│  ┌────────────────────────┐  │
│  │     Docker Compose     │  │
│  │                        │  │
│  │  openclaw-gateway      │  │
│  │  chromium (headless)   │  │
│  │  workspace-sync        │  │
│  └────────────────────────┘  │
│                              │
│  UFW + Hetzner Firewall      │
│  Gateway: 127.0.0.1 only     │
└──────────────────────────────┘
               │
               v (optional)
┌──────────────────────────────┐
│  Remote State Backend        │
│  GCS or local file (default) │
└──────────────────────────────┘
```

## Configuration

### Override System

Personal services, extra Make targets, addon scripts, and local Ansible plays use native override files that are gitignored. The same pattern applies at every layer:

| Layer | What to customize | Override file | Template | Required? | Copy when |
|-------|-------------------|---------------|----------|-----------|-----------|
| Terraform | State backend | `terraform/envs/prod/backend.tf` | `backend.tf.example` | Required | Before `make init` |
| Terraform | Infrastructure variables | `terraform/envs/prod/terraform.tfvars` | `terraform.tfvars.example` | Required | Before `make plan` |
| Docker | Extra services | `docker-compose.override.yml` | `docker-compose.override.example.yml` | Optional | **Before `make bootstrap`** |
| Make | Extra targets | `Makefile.local` | `Makefile.local.example` | Optional | Anytime |
| Ansible | Extra plays | `ansible/site.local.yml` | `ansible/site.local.example.yml` | Optional | Anytime |
| Scripts | Addon scripts | `scripts/local/` | `scripts/local.example/` | Optional | Anytime |

**Docker Compose:** `docker-compose.override.yml` is automatically merged —
no flags needed. Use it to add services or extend the gateway.

**Makefile:** `Makefile.local` is loaded via `-include`. All variables from
the main Makefile are available.

**Ansible:** `ansible/site.local.yml` is used instead of `site.yml` when it
exists. It should import `site.yml` first, then add your local plays. Local
plays live in `ansible/plays/` with a `.local.yml` suffix (gitignored).

### Server Sizing

Default: CX23 (2 vCPU, 4 GB RAM). To change, edit `terraform/envs/prod/terraform.tfvars` (copy from `terraform.tfvars.example` if you haven't already):

```hcl
server_type = "cx32"  # 4 vCPU, 8 GB RAM
```

See [Hetzner Cloud pricing](https://www.hetzner.com/cloud#pricing).

### Firewall / Network Access

By default SSH (port 22) is open to `0.0.0.0/0`. Restrict this before going to production.

**Option A — Restrict to your IP:**

```bash
# In secrets/inputs.sh
export TF_VAR_ssh_allowed_cidrs='["203.0.113.50/32"]'
source secrets/inputs.sh && make plan && make apply
```

**Option B — Tailscale VPN (recommended):**

Tailscale creates a private WireGuard mesh so SSH is reachable only from devices on your tailnet. The pre-auth key is generated automatically by Terraform — no need to create one manually in the Tailscale console.

> **Tailscale is optional.** If you skip these steps, set `TF_VAR_enable_tailscale=false` (the default) and `make apply` ignores all Tailscale resources. You can add Tailscale at any time by setting the vars below and re-running `make apply`.

1. Create an OAuth client at [login.tailscale.com/admin/settings/oauth](https://login.tailscale.com/admin/settings/oauth).

   Required scopes: `auth_keys:write`, `settings:write`, `dns:write` — and `acls:write` if you want Terraform to manage your tailnet ACL.

2. Add to `secrets/inputs.sh`:

   ```bash
   export TF_VAR_enable_tailscale=true
   export TF_VAR_tailscale_oauth_client_id="tskey-client-..."
   export TF_VAR_tailscale_oauth_client_secret="tskey-secret-..."
   ```

3. Apply infrastructure (generates the auth key):

   ```bash
   source secrets/inputs.sh && make apply
   ```

   This can be your initial `make apply` (Quick Start step 5) or a re-run on an existing VPS — both work. Without the OAuth vars, `make apply` skips all Tailscale resources.

4. Bootstrap — installs and registers Tailscale, deploys serve config:

   ```bash
   make bootstrap
   ```

5. Lock SSH to Tailscale-only:

   ```bash
   make tailscale-enable
   ```

   This verifies the Tailscale connection is working, then automatically removes public SSH access via Terraform. If verification fails, it aborts and SSH stays open.

6. Switch your make commands to use the Tailscale hostname:

   ```bash
   # secrets/inputs.sh
   export SERVER_IP="openclaw-prod"   # MagicDNS — stable across rebuilds
   source secrets/inputs.sh
   ```

   This is a one-time manual edit to your local `inputs.sh` — `make` doesn't write back to shell config files.

7. *(Optional)* Update `openclaw.json` to enable Tailscale-based gateway auth — skip this if you only want SSH access and don't need the dashboard accessible via Tailscale HTTPS:

   ```json
   {
     "gateway": {
       "auth": { "allowTailscale": true },
       "controlUi": {
         "allowInsecureAuth": true,
         "allowedOrigins": ["localhost", "127.0.0.1", "https://<your-node>.tailXXXX.ts.net"]
       },
       "trustedProxies": ["172.20.0.0/24"]
     }
   }
   ```

   Then: `make deploy`

   > `allowTailscale` authenticates dashboard users via Tailscale identity headers.
   >
   > `allowInsecureAuth` lets the control UI authenticate over plain HTTP — safe because it's only reachable inside your tailnet.
   >
   > `allowedOrigins` is required since OpenClaw v2026.3.2 for any non-loopback bind. Include `localhost` and `127.0.0.1` for SSH-tunnel access, plus the Tailscale HTTPS URL for Tailscale Serve access.
   >
   > `trustedProxies` is required when the gateway runs in Docker behind Tailscale Serve — traffic arrives from the Docker bridge with the real client IP in `X-Forwarded-For`. Without this, `allowTailscale` never fires. The value `172.20.0.0/24` matches the Docker Compose network subnet defined in `docker-compose.yml`. To verify: `docker network inspect openclaw_default | grep -A2 Subnet`

   > Note: you'll need to `source secrets/inputs.sh` in each new shell session for `SERVER_IP` to be set.

> **Emergency access:** [Hetzner web console](https://console.hetzner.cloud/) → server → Console.

### Remote State Backend

Default backend is local (no setup needed). See [docs/remote-state.md](docs/remote-state.md) for GCS setup, migration from local state, and CI authentication.

### AI Providers

OpenClaw defaults to Anthropic Claude. To switch providers, update `openclaw.json`:

```json
{
  "agents": {
    "defaults": {
      "model": { "primary": "openai/gpt-4" }
    }
  },
  "auth": {
    "profiles": {
      "openai:main": { "provider": "openai", "mode": "token" }
    }
  }
}
```

Add the corresponding key to `secrets/.env` (e.g. `OPENAI_API_KEY=sk-...`) and run `make deploy`.

Supported providers: Anthropic, OpenAI, DeepSeek, and local models via Ollama/LM Studio. See [OpenClaw provider docs](https://docs.openclaw.ai/providers).

### Agent & Channel Configuration

See **[docs/openclaw-config.md](docs/openclaw-config.md)** for:

- Telegram channel settings (retry, access control, groups, mention patterns)
- Session architecture (DM vs group chats)
- Commands, permissions, and elevated access
- Troubleshooting (polling stalls, network errors, rate limits)

## Make Targets

**Infrastructure:**

```bash
make init       # Initialize Terraform
make plan       # Preview infrastructure changes
make apply      # Apply infrastructure changes
make destroy    # Destroy all infrastructure
make validate   # Validate Terraform + config
make fmt        # Format Terraform files
```

**Deployment:**

```bash
make bootstrap        # First-time setup (dirs, Docker build, config push, start)
make deploy           # Push config/env to VPS and restart containers
make deploy REBUILD=1 # Also rebuild Docker images (use after docker/ changes)
```

If you are using Anthropic models, you can also set up subscription auth with:

```bash
make setup-auth       # Configure Claude subscription auth on VPS
```

If other models, see <https://docs.openclaw.ai/providers> for provider-specific auth setup.

**Operations:**

```bash
make status       # Container status, Tailscale, etc.
make logs         # Stream Docker logs
make ssh          # SSH to VPS as openclaw user
make tunnel       # SSH tunnel to gateway (localhost:18789)
make exec CMD=""  # Run command in gateway container
```

**Tailscale:**

```bash
make tailscale-enable   # Install Tailscale, verify, and lock down public SSH
make tailscale-setup    # Install and register Tailscale only, no SSH lockdown
make tailscale-status   # Check Tailscale connection status
make tailscale-ip       # Get Tailscale IP
make tailscale-up       # Manually authenticate Tailscale
```

> `TAILSCALE_AUTH_KEY` is read automatically from `terraform output` when `enable_tailscale=true` — no manual key needed. To override, set it explicitly in your shell before running make.
>
> **Security note:** The auth key is stored in Terraform state. Protect your state file (`terraform/envs/prod/terraform.tfstate`, gitignored) or GCS bucket with the same care as `secrets/inputs.sh`. Anyone with read access to state can extract the key.

**Backup & Restore:**

```bash
make backup-now   # Trigger backup immediately
make backup-pull  # Download latest backup archive locally
make restore      # List available backups (dry-run — safe)
make restore EXECUTE=1 BACKUP=<file>  # Restore from backup
```

**Optional add-ons** (from `Makefile.local`):

```bash
make addon-weather    # Install morning weather cron
make patch-devices    # Fix device pairing issues
```

## Common Workflows

### Update OpenClaw

Check for breaking changes first:

```bash
gh release list --repo openclaw/openclaw --limit 10
```

Then:

```bash
make backup-now                    # always backup before upgrading
# Edit docker/Dockerfile — bump OPENCLAW_VERSION
make deploy REBUILD=1
make logs
```

### Update Configuration

`openclaw.json` is gitignored — create it from `openclaw.example.json` if you haven't already.

```bash
vim openclaw.json
make deploy
```

### Backup and Restore

Backups run daily at 03:00 UTC via systemd timer.

```bash
make backup-now     # trigger immediately
make backup-pull    # download latest archive locally

make restore        # list available backups (safe, no changes)
make restore EXECUTE=1 BACKUP=openclaw_backup_20260101_030000.tar.gz
```

`make restore` without `EXECUTE=1` is always safe. With `EXECUTE=1` it stops containers, creates a safety backup of current state, extracts the archive, and restarts.

### Access the Gateway

The gateway binds to `127.0.0.1:18789` (localhost only).

**Via SSH tunnel:**

```bash
make tunnel  # localhost:18789 -> VPS:18789
```

Open `http://localhost:18789` and paste your `OPENCLAW_GATEWAY_TOKEN`.

**Via Tailscale Serve** (if Tailscale is enabled):

`make bootstrap` deploys the serve config automatically — no manual SSH needed. The gateway is available at:

```
https://openclaw-prod.<tailnet>.ts.net
```

from any tailnet device. To expose additional services (e.g. ports 4000, 3001), edit `ansible/templates/tailscale-serve.json.j2` and run `make deploy`. See [docs/tailscale.md](docs/tailscale.md) for the full serve config reference.

> Use Serve, not Funnel. Funnel exposes the service to the public internet.

## Troubleshooting

**Terraform init fails** — if using GCS backend, ensure authentication is configured. Run `gcloud auth application-default login` first. The default backend is local and requires no extra setup.

**Container won't start:**

```bash
make logs
make ssh
docker compose -f ~/openclaw/docker-compose.yml ps
```

Common causes: missing `.env` variables, invalid `openclaw.json`, API key issues. Fix with `make deploy`.

**Can't SSH to VPS** — if `ssh_allowed_cidrs='[]'` (Tailscale-only mode), SSH via Tailscale IP or MagicDNS hostname. Emergency access via [Hetzner web console](https://console.hetzner.cloud/).

**SSH host key changed** (after rebuilding the VPS):

```bash
ssh-keygen -R <old_vps_ip>
```

**Permission denied on `~/.openclaw`** — Docker took ownership via volume mount:

```bash
ssh openclaw@VPS_IP "sudo chown -R openclaw:openclaw ~/.openclaw"
```

**Dashboard shows "Pairing Required":**

- Check `trustedProxies` is set in `openclaw.json` (see [Firewall / Network Access](#firewall--network-access))
- Or the browser device needs pairing: `make patch-devices` (from `Makefile.local`)

**API billing error** — verify key in `~/openclaw/.env` on the VPS, or re-run `make setup-auth` for subscription auth.

## CI/CD

Built-in CI validates and tests Terraform (fmt, validate, tflint, native tests). Example workflows for `terraform plan` and `terraform apply` are in `.github/workflows/*.example.yml`. An optional GitOps workflow enables automatic Ansible-based deployments on push.

See [docs/cicd.md](docs/cicd.md) for required GitHub Variables, Secrets, and approval gate setup.

## Advanced Topics

| Topic | Doc |
| ----- | --- |
| Tailscale serve config | [docs/tailscale.md](docs/tailscale.md) |
| Skills (ClawHub) | [docs/skills.md](docs/skills.md) |
| Headless browser | [docs/headless-browser.md](docs/headless-browser.md) |
| Multi-agent setup | [docs/agents.md](docs/agents.md) |
| Workspace Git sync | [docs/workspace-git-sync.md](docs/workspace-git-sync.md) |
| Morning weather report | [docs/addons/weather-report.md](docs/addons/weather-report.md) |
| CI/CD setup | [docs/cicd.md](docs/cicd.md) |
| GitOps auto-deploy | [docs/gitops-auto-deploy.md](docs/gitops-auto-deploy.md) |
| Security hardening | [docs/security-hardening.md](docs/security-hardening.md) |
| Version management | [docs/versions.md](docs/versions.md) |
| Remote state backend | [docs/remote-state.md](docs/remote-state.md) |
| Secrets reference | [docs/secrets.md](docs/secrets.md) |

## Security

See [SECURITY.md](SECURITY.md) for the full security policy and threat model.

Key points:

- Default SSH is open to `0.0.0.0/0` — restrict before production (see [Firewall / Network Access](#firewall--network-access))
- Never commit `secrets/inputs.sh` or `secrets/.env`
- Gateway binds to `127.0.0.1` — never directly exposed to the internet
- Use Tailscale for zero public SSH exposure

## Infrastructure Costs

This setup uses a small shared VPS (default: CX23) plus minimal object storage for Terraform state. See [Hetzner Cloud pricing](https://www.hetzner.com/cloud#pricing). API costs (Anthropic, OpenAI, etc.) are separate.

## License

MIT — see [LICENSE](LICENSE).
