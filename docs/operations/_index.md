---
title: "Operations"
weight: 4
---

All day-to-day operations go through `make`. Run `source secrets/inputs.sh` before any make target that touches the VPS.

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

**Backup & Restore:** see [backup-restore.md](backup-restore.md)

```bash
make backup-now   # Trigger backup immediately
make backup-pull  # Download latest backup archive locally
make restore      # List available backups (dry-run — safe)
make restore EXECUTE=1 BACKUP=<file>  # Restore from backup
```

**Health Monitoring** (opt-in, Telegram alerts):

```bash
make monitor-enable   # Deploy and start monitoring timer (5-min interval)
make monitor-disable  # Stop and remove monitoring
make monitor-status   # Show timer status, recent logs, and state
make monitor-test     # Run one check cycle manually
```

See [Health Monitoring](#health-monitoring) below for setup and configuration.

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

See **[backup-restore.md](backup-restore.md)** for the full workflow, backup contents, and undo instructions.

### Access the Gateway

The gateway binds to `127.0.0.1:18789` (localhost only).

**Via SSH tunnel:**

```bash
make tunnel  # localhost:18789 -> VPS:18789
```

Open `http://localhost:18789` and paste your `OPENCLAW_GATEWAY_TOKEN`.

**Via Tailscale Serve** (if Tailscale is enabled):

`make bootstrap` deploys the Tailscale serve config automatically — no manual steps needed. The gateway is available at:

```text
https://openclaw-prod.<tailnet>.ts.net
```

from any tailnet device. See [Tailscale](/docs/tailscale.md) for serve config details and troubleshooting.

> Use Serve, not Funnel. Funnel exposes the service to the public internet.

## Health Monitoring

Optional health monitoring that checks the VPS every 5 minutes and sends Telegram alerts on failure.

### What It Checks

| Check | Threshold |
|-------|-----------|
| Container health | All containers must be running |
| HTTP endpoint | `http://127.0.0.1:18789/health` must respond within 5s |
| Disk usage | Warn at 85%, critical at 95% |
| Memory usage | Warn at 90% |
| Backup recency | Alert if no backup in 48 hours |

Alerts have a 1-hour cooldown per check to prevent storms. A check must fail twice in a row before an alert is sent.

### Prerequisites

1. **Telegram bot token** — set `TELEGRAM_BOT_TOKEN` in your `.env` (or SOPS-encrypted `.env.enc`)
2. **Chat ID** — automatically read from `openclaw.json` → `channels.telegram.allowFrom[0]`

### Setup

```bash
make deploy                  # deploys the script to ~/scripts/ on the VPS
make monitor-enable          # installs systemd timer and starts it
```

Verify it's running:

```bash
make monitor-status
```

### Testing

Trigger one check cycle manually (will send an alert if any check fails):

```bash
make monitor-test
```

### State

Monitoring state is stored at `~/.openclaw/monitor-state.json` on the VPS. Tracks last alert times, consecutive failures, and previously-failing checks (for recovery notifications).

### Disabling

```bash
make monitor-disable
```

This stops the timer and removes the systemd files, monitor script, and state file (`~/.openclaw/monitor-state.json`) from the VPS.

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

**Dashboard shows "Pairing Required"** — check `trustedProxies` is set in `openclaw.json`.

**API billing error** — verify key in `~/openclaw/.env` on the VPS, or re-run `make setup-auth` for subscription auth.
