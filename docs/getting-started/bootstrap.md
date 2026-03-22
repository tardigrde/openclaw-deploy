---
title: "Deployment & Bootstrap"
weight: 20
---

Continues from [Installation](/getting-started/installation/). Run `source secrets/inputs.sh` before any make target that touches the VPS.

## 5. Provision the VPS

```bash
source secrets/inputs.sh
make init
make plan
make apply
```

## 6. Configure container secrets

```bash
cp secrets/.env.example secrets/.env
vim secrets/.env
```

Required: `OPENCLAW_GATEWAY_TOKEN`, `ANTHROPIC_API_KEY` (or leave empty for subscription auth), `TELEGRAM_BOT_TOKEN`. See [Secrets Reference](/configuration/secrets/) for the full variable reference.

## 7. (Optional) Encrypt secrets at rest with SOPS

Complete step 6 first — `make secrets-encrypt` reads `secrets/.env`.

```bash
make secrets-generate-key   # generates secrets/age-key.txt and prints the public key
# Edit .sops.yaml — paste the age public key printed above into the `age:` field
make secrets-encrypt        # encrypts secrets/.env → secrets/.env.enc
```

Plain `.env` works for local use. SOPS is **required** for the [GitOps auto-deploy workflow](/operations/gitops-auto-deploy/). See [Secrets Reference § SOPS](/configuration/secrets/#sops-encryption-optional-for-local-required-for-ci) for the full workflow.

> **Adding extra services?** If you plan to run additional services (e.g. Mission Control), copy `docker-compose.override.example.yml → docker-compose.override.yml` before the next step — it cannot be merged in after bootstrap without re-running it.
>
> ```bash
> cp docker-compose.override.example.yml docker-compose.override.yml
> vim docker-compose.override.yml
> ```

## 8. Bootstrap OpenClaw

```bash
source secrets/inputs.sh
make bootstrap
```

Creates directories, builds Docker images, pushes config, and starts containers — everything in one command.

> **Claude subscription auth:** If you left `ANTHROPIC_API_KEY` empty, run `make setup-auth` after bootstrap to link your Claude subscription.

## 9. Verify

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

## Access the Gateway

The gateway binds to `127.0.0.1:18789` (localhost only).

**Via SSH tunnel** (always available):

```bash
make tunnel  # localhost:18789 -> VPS:18789
```

Open `http://localhost:18789` and paste your `OPENCLAW_GATEWAY_TOKEN`.

**Via Tailscale Serve** (if Tailscale is enabled):

```bash
ssh -i $SSH_KEY openclaw@<tailscale-ip>
sudo tailscale serve --bg 18789
sudo tailscale serve status  # prints your HTTPS URL
```

Dashboard available at `https://openclaw-prod.<tailnet>.ts.net` from any tailnet device.
