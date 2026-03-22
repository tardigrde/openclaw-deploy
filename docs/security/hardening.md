---
title: "Security Hardening"
weight: 130
---
# Security Hardening

Overview of all security controls applied to the OpenClaw VPS.

## Firewall

Two firewall layers run in series.

### Hetzner Cloud Firewall (network-level)

Managed in Terraform (`terraform/modules/hetzner-vps/main.tf`). Applied at the hypervisor — traffic is dropped before it reaches the OS.

| Direction | Protocol | Port      | Source                        | Condition              |
|-----------|----------|-----------|-------------------------------|------------------------|
| Inbound   | TCP      | 22        | `ssh_allowed_cidrs` variable  | Always                 |
| Inbound   | UDP      | 41641     | `0.0.0.0/0`, `::/0`           | Only if Tailscale on   |
| Outbound  | TCP      | 1–65535   | `0.0.0.0/0`, `::/0`           | Always                 |
| Outbound  | UDP      | 1–65535   | `0.0.0.0/0`, `::/0`           | Always                 |
| Outbound  | ICMP     | —         | `0.0.0.0/0`, `::/0`           | Always                 |

`ssh_allowed_cidrs` defaults to `["0.0.0.0/0"]`. For tighter access, set it to specific IPs in `secrets/inputs.sh`, or set it to `[]` to block public SSH entirely (Tailscale-only mode).

### UFW (OS-level)

Base rules configured during cloud-init. Tailscale rule added by Ansible (`plays/tailscale.yml`) during bootstrap.

```
ufw default deny incoming
ufw default allow outgoing
ufw allow ssh
ufw allow 41641/udp  # Tailscale — added by Ansible, not cloud-init
```

### IPv6

IPv6 is disabled on all OpenClaw VPS instances at the OS level via sysctl. UFW only manages IPv4; Hetzner Cloud assigns a public IPv6 address to every VPS by default, meaning the server has an unfiltered IPv6 interface exposed to the internet unless explicitly addressed.

Rather than maintaining separate `ip6tables` rules, we disable IPv6 entirely. This aligns with the current IPv4-only Tailscale + UFW setup.

A sysctl configuration file is written during cloud-init:

```
/etc/sysctl.d/99-disable-ipv6.conf
```

```ini
net.ipv6.conf.all.disable_ipv6 = 1
net.ipv6.conf.default.disable_ipv6 = 1
net.ipv6.conf.lo.disable_ipv6 = 1
```

**Applying to existing servers:**

Cloud-init only runs on first boot. To apply this to an existing server:

```bash
# One-time: via Ansible bootstrap (recommended)
make bootstrap

# Or via the Hetzner web console (root shell):
sysctl --system | grep ipv6
```

**Verifying:**

```bash
# Should return 1 (disabled)
ssh openclaw@<server-ip> 'cat /proc/sys/net/ipv6/conf/all/disable_ipv6'

# Should show no IPv6 addresses (except link-local fe80::)
ssh openclaw@<server-ip> 'ip -6 addr show'
```

---

## SSH Hardening

### sshd drop-in (`/etc/ssh/sshd_config.d/99-hardening.conf`)

Written during cloud-init (permissions `0600`, owner `root`):

```
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
```

Key-based authentication only. Root login is disabled; all access is via the `openclaw` user (passwordless sudo, scoped to specific commands — see [Sudo Permissions](#sudo-permissions)).

### fail2ban (`/etc/fail2ban/jail.local`)

Installed and started during cloud-init:

```ini
[sshd]
enabled  = true
port     = ssh
filter   = sshd
logpath  = /var/log/auth.log
maxretry = 3
bantime  = 1h
findtime = 600
```

Bans IPs after 3 failed attempts within 10 minutes. Ban duration is 1 hour.

### Applying to an existing server

Cloud-init only runs on first boot. To apply SSH hardening to a running server, follow the checklist below, then run these commands manually:

```bash
# 1. Write sshd drop-in
sudo tee /etc/ssh/sshd_config.d/99-hardening.conf > /dev/null << 'EOF'
PasswordAuthentication no
PermitRootLogin no
MaxAuthTries 3
LoginGraceTime 30
X11Forwarding no
EOF
sudo chmod 600 /etc/ssh/sshd_config.d/99-hardening.conf

# 2. Write fail2ban jail
sudo apt-get install -y fail2ban
sudo tee /etc/fail2ban/jail.local > /dev/null << 'EOF'
[sshd]
enabled = true
port = ssh
filter = sshd
logpath = /var/log/auth.log
maxretry = 3
bantime = 1h
findtime = 600
EOF

# 3. Validate sshd config before reloading — stop here if this fails
sudo sshd -t && echo CONFIG OK

# 4. Reload (preserves existing sessions)
sudo systemctl reload ssh
sudo systemctl reload fail2ban
```

Safety checklist for applying to a running server: see [SSH Hardening Safety Checklist](#ssh-hardening-safety-checklist) below.

---

## Sudo Permissions

The `openclaw` user has passwordless sudo, scoped to specific commands only (no `NOPASSWD:ALL`).

Containers are managed via `docker compose` (no sudo needed — the user is in the `docker` group). The sudo whitelist is for system-level operations only.

### Allowed commands

| Command | Purpose |
|---|---|
| `/usr/bin/tailscale status` | View VPN status (used by `make status`) |
| `/usr/bin/tailscale up` | Re-authenticate Tailscale (used by `make tailscale-up`) |
| `/usr/sbin/ufw status` | View firewall status (read-only) |
| `/usr/bin/journalctl *` | Read system/service logs for debugging |
| `/usr/bin/systemctl daemon-reload` | Reload systemd after installing units |
| `/usr/bin/systemctl restart docker` | Restart Docker daemon if it crashes |
| `/usr/bin/fail2ban-client status *` | View fail2ban jail status (used by `make status`) |

**Not included by design:**
- `docker *` — redundant (user is in the `docker` group) and equivalent to full root
- `systemctl restart openclaw-*` — these are Docker containers, not systemd services; use `docker compose restart`
- `apt upgrade/autoremove` — handled by `unattended-upgrades`

### Applying to an existing server

Cloud-init only runs on first boot. To apply scoped sudo on a running server:

```bash
sudo tee /etc/sudoers.d/openclaw > /dev/null << 'EOF'
# OpenClaw user sudo permissions — scoped for security
openclaw ALL=(root) NOPASSWD: /usr/bin/tailscale status
openclaw ALL=(root) NOPASSWD: /usr/bin/tailscale up
openclaw ALL=(root) NOPASSWD: /usr/sbin/ufw status
openclaw ALL=(root) NOPASSWD: /usr/bin/journalctl *
openclaw ALL=(root) NOPASSWD: /usr/bin/systemctl daemon-reload
openclaw ALL=(root) NOPASSWD: /usr/bin/systemctl restart docker
openclaw ALL=(root) NOPASSWD: /usr/bin/fail2ban-client status *
EOF
sudo chmod 440 /etc/sudoers.d/openclaw

# Verify — this should succeed
sudo -u openclaw sudo -n tailscale status

# Verify dangerous commands are blocked — these should fail
sudo -u openclaw sudo -n whoami          # → NOT in sudoers
sudo -u openclaw sudo -n cat /etc/shadow # → NOT in sudoers
```

**Before applying to production:** open two SSH sessions, apply in one, and verify the other still works. The Hetzner Cloud console (web VNC) is the safety net if you lock yourself out.

---

## Tailscale

Tailscale provides a WireGuard-based VPN mesh. When enabled, it allows SSH and gateway access over the Tailnet without exposing any ports to the public internet.

**Terraform variable:**

| Variable           | Default | Where set                                          | Description                        |
|--------------------|---------|----------------------------------------------------|------------------------------------|
| `enable_tailscale` | `false` | `terraform/envs/prod/terraform.tfvars` (copy from `terraform.tfvars.example`) | Opens Hetzner firewall UDP 41641   |

The auth key is **not** a Terraform variable. It is passed to Ansible as `TAILSCALE_AUTH_KEY` (set in `secrets/inputs.sh`).

**Ansible provisioning (`ansible/plays/tailscale.yml`):**

Runs as part of `make bootstrap`, or standalone via `make tailscale-setup`. Skipped if `TAILSCALE_AUTH_KEY` is unset.

```bash
curl -fsSL https://tailscale.com/install.sh | sh
systemctl enable --now tailscaled
ufw allow 41641/udp
tailscale up --auth-key <key> --accept-routes --hostname openclaw-prod
```

If no auth key is set, run `make tailscale-up` after `make bootstrap` to authenticate interactively.

**Useful commands:**

```bash
make tailscale-status   # Show connection state and peers
make tailscale-ip       # Get Tailscale IPv4 address (100.x.x.x)
make tailscale-up       # Re-authenticate Tailscale manually
```

**Gateway allowlisting:**
The OpenClaw gateway's `allowTailscale: true` setting in `openclaw.json` trusts requests arriving over Tailscale without requiring an explicit token.

---

## Secrets Encryption (SOPS + age)

All secrets are encrypted at rest using [SOPS](https://github.com/getsops/sops) with [age](https://age-encryption.org) keys. The encrypted file `secrets/.env.enc` is committed to git — safe to share, since only keyholders can decrypt.

### How It Works

| Layer | Mechanism |
|-------|-----------|
| **At rest (git)** | `secrets/.env.enc` — AES-256-GCM encrypted by SOPS, safe to commit |
| **In transit (CI)** | GitHub Actions decrypts using `SOPS_AGE_KEY` secret before `make deploy` |
| **On VPS (docker-compose)** | Ansible decrypts `.env.enc` → `.env` temporarily, then `shred -u` after containers start |
| **On VPS (OpenClaw native)** | Gateway container decrypts `.env.enc` on-the-fly via SOPS exec provider |

### Key Management

- **Age key**: Generated once with `age-keygen`, stored locally in `secrets/age-key.txt` (gitignored)
- **GitHub secret**: Full content of `age-key.txt` stored as `SOPS_AGE_KEY`
- **VPS**: Age key mounted read-only into gateway container at `/home/node/.config/sops/age/keys.txt`

### Local Workflow

```bash
# First-time setup
make secrets-generate-key              # Creates secrets/age-key.txt
# Add the public key to .sops.yaml, then:
make secrets-encrypt                   # Encrypts secrets/.env → secrets/.env.enc
git add secrets/.env.enc && git commit # Commit encrypted file

# Day-to-day
make secrets-edit                      # Edit encrypted file in-place (opens $EDITOR)
make secrets-decrypt                   # Decrypt to secrets/.env for local use

# Deploy (decrypts automatically in CI; locally run secrets-decrypt first)
make deploy
```

### OpenClaw Native SOPS Provider

The gateway container uses SOPS as an exec-based secrets provider (`openclaw.json` → `secrets.providers.sops_env`). This allows OpenClaw to decrypt individual secrets on-the-fly without persisting plaintext on disk.

The encrypted `.env.enc` is mounted into the container at `/home/node/.openclaw/secrets/.env.enc`, and the age key is available via `SOPS_AGE_KEY_FILE`. Individual secrets are extracted via a shell command that decrypts and greps the value:

```sh
sops -d /home/node/.openclaw/secrets/.env.enc | grep -E '^{{secret}}=' | cut -d= -f2- | tr -d '\n'
```

### First-Time Setup Checklist

1. `make secrets-generate-key` — creates `secrets/age-key.txt`
2. Copy the **public key** (shown after generation) into `.sops.yaml` under `age:`
3. `make secrets-encrypt` — creates `secrets/.env.enc`
4. Add `SOPS_AGE_KEY` to GitHub Secrets (Settings → Secrets → Actions) — paste the full content of `secrets/age-key.txt`
5. On VPS: ensure age key exists at `/home/openclaw/.config/sops/age/keys.txt` (or set `SOPS_AGE_KEY_FILE` in env)

---

## GitHub Actions

### Validate (`validate.yml`)

Runs on every PR and push to `main`. Fails the build if any of these fail:

- `terraform fmt -check` — formatting
- `terraform validate` — Terraform validity
- `shellcheck` — shell script linting
- `ansible-playbook --syntax-check` — Ansible syntax
- Checkov IaC scan (soft fail — reports but doesn't block)

### Deploy (`deploy.yml`)

Triggers on push to `main` when `docker/`, `docker-compose.yml`, `ansible/`, or `secrets/.env.enc` change.

1. Connects to Tailscale using OAuth credentials (`TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`) with tag `tag:ci-runner`
2. Writes `SSH_PRIVATE_KEY` to a temp key file (`0600`)
3. Installs SOPS, decrypts `secrets/.env.enc` using `SOPS_AGE_KEY` secret
4. Runs `make deploy` (or `make deploy REBUILD=1` if Docker files changed)

Required GitHub secrets: `TAILSCALE_OAUTH_CLIENT_ID`, `TAILSCALE_OAUTH_CLIENT_SECRET`, `SSH_PRIVATE_KEY`, `SERVER_IP`, `SOPS_AGE_KEY`.

Template: `.github/workflows/deploy.yml.example` — copy to `deploy.yml` to enable. See [GitOps auto-deploy](gitops-auto-deploy.md) for full setup.

### Rollback (`rollback.yml`)

Manual workflow dispatch. Takes a Git SHA, checks out that commit, decrypts secrets with SOPS, and runs `make deploy REBUILD=1` to redeploy from that point.

---

## Automatic Security Updates

`unattended-upgrades` is installed and enabled during cloud-init. It applies OS security patches automatically without manual intervention.

---

## SSH Hardening Safety Checklist

Use this when applying SSH hardening to a server that is already running.

### Pre-flight (do BEFORE touching anything)

- Open **two SSH sessions** to the VPS as the `openclaw` user — one to apply changes, one as a bail-out lifeline
- Verify `openclaw` user SSH works — hardening sets `PermitRootLogin no`, so root SSH will be lost
- Verify `sudo -n tailscale status` works (scoped passwordless sudo is configured in cloud-init)
- Note your current IP — `echo $SSH_CLIENT` — so you can unban yourself if fail2ban triggers
- Confirm `ssh-add -l` is non-empty, or that you're using `-i <keyfile>` directly

### Apply changes (keep the second session open throughout)

- Write `/etc/ssh/sshd_config.d/99-hardening.conf` with `0600` permissions owned by `root`
- Write `/etc/fail2ban/jail.local`
- Install fail2ban: `sudo apt-get install -y fail2ban`
- **Validate sshd config: `sudo sshd -t`** — if this fails, do not proceed
- Reload sshd: `sudo systemctl reload ssh`
- Verify the second session still responds
- Reload fail2ban: `sudo systemctl reload fail2ban`

### Post-flight verification

- Open a **third terminal** and confirm a fresh SSH session connects
- Verify root login is rejected: `ssh root@<ip>` should return `Permission denied`
- Check fail2ban: `sudo systemctl status fail2ban` and `sudo fail2ban-client status sshd`

### Rollback (if locked out)

- Use **Hetzner Cloud console (web VNC)** to regain access
- Remove `/etc/ssh/sshd_config.d/99-hardening.conf` and run `sudo systemctl reload ssh`
- Unban your IP: `sudo fail2ban-client set sshd unbanip <YOUR_IP>`
