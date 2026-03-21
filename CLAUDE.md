# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

> Note: it should be kept concise.

> If `docs/local/CLAUDE.md` exists, read it now — it contains private deployment instructions for this instance.

## Overview

This is an infrastructure-as-code repository for deploying the [OpenClaw](https://openclaw.ai) AI coding assistant on a Hetzner Cloud VPS.

## Common Commands

All operations go through `make`. The Makefile reads VPS IP from Terraform state automatically.

Prerequisite to all operating make targets:

```bash
source secrets/inputs.sh
```

### Infrastructure
```bash
make init      # Initialize Terraform (run once, sets up backend)
make plan      # Preview infrastructure changes
make apply     # Create/update VPS, firewall, etc.
make validate  # Validate Terraform + shell scripts + config JSON
make fmt       # Format Terraform files
```

### Deployment
```bash
make bootstrap        # First-time setup after `apply` (dirs, clones MC, builds Docker, sets up backup timer, starts containers)
make deploy           # Push config/env to VPS and restart containers (day-to-day)
make deploy REBUILD=1 # Also rebuild Docker images (use after docker/ or docker-compose.yml changes)
make setup-auth       # Configure Claude subscription auth on VPS
make backup-now       # Trigger backup immediately on VPS
make backup-pull      # Download latest backup archive locally
make restore          # List available backups (dry-run; safe)
make restore EXECUTE=1 BACKUP=<file>  # Actually restore from backup
```

Local targets (in `Makefile.local`, gitignored — copy from `Makefile.local.example`):
```bash
make patch-devices    # Fix device pairing issues (CLI scopes + control UI)
make addon-weather    # Install morning-weather cron (optional)
```

Playbook: `ansible/site.yml` — imports modular plays from `ansible/plays/`.
Ansible tags: `bootstrap`, `tailscale`, `docker`, `config`, `start` (run by default on `make bootstrap`).
Tags that never run by default: `setup_auth`, `patch_devices`, `backup_now`, `backup_pull`, `restore`, `addon-weather-report`.

**CI runs Terraform only** (`terraform plan` on PRs, `terraform apply` on manual dispatch). Ansible is never run in CI — all `make bootstrap` / `make deploy` / `make tailscale-setup` operations are local only.
Dry run: `ANSIBLE_CONFIG=ansible/ansible.cfg ansible-playbook -i "$SERVER_IP," --private-key $SSH_KEY ansible/site.yml --check --diff`

**Update cycle** (bump OpenClaw version or MC source):
1. Check changelogs for breaking changes or data migrations:
   ```bash
   gh release list --repo openclaw/openclaw --limit 10
   gh release list --repo crshdn/mission-control --limit 10
   ```
2. `make backup-now` — backs up gateway data AND Mission Control database (do this before every upgrade)
3. Edit `docker/Dockerfile` ARG to change OpenClaw version
4. `make deploy REBUILD=1` — re-clones/pulls MC from GitHub, rebuilds all images, restarts containers

### Operations
```bash
make status       # Check container status, Tailscale, etc.
make logs         # Stream Docker logs
make exec CMD=""  # Run a command in the gateway container
```

## Security Notes

- **fail2ban is active** with `maxretry=3` and `bantime=1h`. Avoid repeated failed SSH attempts (e.g. trying to connect as root, using wrong keys) or you will get banned. To unban: use the Hetzner web console → Console tab, then run `sudo fail2ban-client unban --all`.
- **Root login is blocked by sshd** — always connect as `openclaw`. `make ssh-root` is disabled for this reason. Any SSH attempt as root counts toward fail2ban. For emergency root access use the Hetzner web console.
- **If workspace `.git` is root-owned** (from an accidental `sudo` run): use the Hetzner console to run `chown -R openclaw:openclaw /home/openclaw/.openclaw/workspace/.git`, then `make workspace-sync`.
- **`make bootstrap` must be run as root** (via Hetzner console or before SSH hardening applies) — it installs Docker and sets up system-level config. Day-to-day `make deploy` runs as the `openclaw` user with scoped sudo only.
- **SOPS-encrypted `.env`** — the server uses a SOPS-encrypted env file (`secrets/.env.enc`) decrypted at runtime via an age key. API keys (OPENROUTER, ANTHROPIC, etc.) are stored there, not in plaintext. Use `make secrets-edit` to modify and `make secrets-encrypt`/`make secrets-decrypt` for manual operations.

### Secrets Setup (one-time)
```bash
cp secrets/inputs.example.sh secrets/inputs.sh
# Edit secrets/inputs.sh with HCLOUD_TOKEN, SSH key fingerprint, etc.
source secrets/inputs.sh
```
