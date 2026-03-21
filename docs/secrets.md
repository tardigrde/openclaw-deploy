# Secrets Reference

Two secret files are required. Neither is ever committed to git.

## `secrets/inputs.sh` — Infrastructure config

Sourced by the Makefile at parse time (and re-exported for Terraform). Contains deployment-level config, not runtime secrets.

```bash
cp secrets/inputs.example.sh secrets/inputs.sh
vim secrets/inputs.sh
```

| Variable | Required | Description |
|----------|----------|-------------|
| `HCLOUD_TOKEN` | Yes | Hetzner Cloud API token — [console.hetzner.cloud](https://console.hetzner.cloud/) → Security → API Tokens |
| `SSH_KEY_FINGERPRINT` | Yes | Fingerprint of your SSH key uploaded to Hetzner — console → Security → SSH Keys |
| `SERVER_IP` | Tailscale only | Set to `openclaw-prod` (MagicDNS) after locking down SSH. Leave unset to auto-detect from Terraform output. |
| `TAILSCALE_AUTH_KEY` | Tailscale only | Reusable pre-authorized key from [login.tailscale.com/admin/settings/keys](https://login.tailscale.com/admin/settings/keys). Must be set before `make bootstrap`. |
| `SSH_KEY` | No | Path to SSH private key. Defaults to `~/.ssh/id_rsa`. |

The Makefile auto-sources `inputs.sh` for Terraform vars. For SSH-based targets (`make ssh`, `make deploy`, etc.), `SERVER_IP` must resolve — either auto-detected from Terraform output or explicitly set.

## `secrets/.env` — Container runtime secrets

Deployed to the VPS by Ansible and loaded by Docker Compose. Contains API keys and service tokens.

```bash
cp secrets/.env.example secrets/.env
vim secrets/.env
```

| Variable | Required | Description |
|----------|----------|-------------|
| `OPENCLAW_GATEWAY_TOKEN` | Yes | Token for accessing the OpenClaw gateway API. Generate with `openssl rand -hex 32`. |
| `ANTHROPIC_API_KEY` | Yes* | Anthropic API key. Leave empty if using subscription auth (`make setup-auth`). |
| `TELEGRAM_BOT_TOKEN` | Yes | Telegram bot token from [@BotFather](https://t.me/botfather). Use a dummy value if not using Telegram. |
| `TELEGRAM_CHAT_ID` | No | Your Telegram user/chat ID. |
| `OPENROUTER_API_KEY` | No | OpenRouter API key for alternative model providers. |
| `BRAVE_API_KEY` | No | Brave Search API key for web search skill. |
| `GH_TOKEN` | No | GitHub personal access token for GitHub skill. |

\* Required unless using `make setup-auth` for Claude subscription auth.

## How secrets reach the VPS

Ansible (called by `make deploy` / `make bootstrap`) uses one of two paths:

1. **`secrets/.env` exists locally** → copied directly to `~/openclaw/.env` on the VPS. Simplest for local-only workflows.
2. **`secrets/.env.enc` + `secrets/age-key.txt` exist** → both are pushed to the VPS, SOPS decrypts `.env.enc` to `.env` there. Used when the plaintext `.env` should never leave your machine.

If neither exists, Ansible warns and containers start without updated secrets.

## SOPS Encryption (optional for local, required for CI)

SOPS encrypts `secrets/.env` at rest using an age key. The encrypted file (`secrets/.env.enc`) is safe to commit.

```bash
# One-time setup
make secrets-generate-key    # generates secrets/age-key.txt + prints public key
# Paste the public key into .sops.yaml (shown after generation)

make secrets-encrypt         # secrets/.env → secrets/.env.enc
git add secrets/.env.enc .sops.yaml
```

Day-to-day editing:

```bash
make secrets-edit            # opens $EDITOR with decrypted content, re-encrypts on save
# or manually:
make secrets-decrypt         # → secrets/.env
vim secrets/.env
make secrets-encrypt         # → secrets/.env.enc
```

SOPS encryption is **required** if you use the [GitOps auto-deploy workflow](gitops-auto-deploy.md) — the CI workflow only handles `.env.enc`, never a plaintext `.env`.

## CI Secrets

The GitOps auto-deploy workflow needs additional GitHub repository secrets beyond what Terraform CI uses. See [docs/gitops-auto-deploy.md](gitops-auto-deploy.md) for the full list.
