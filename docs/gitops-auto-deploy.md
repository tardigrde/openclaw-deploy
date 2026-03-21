# GitOps Auto-Deploy

A GitHub Actions pipeline can automatically deploy to the VPS on every push to `main`. This is **optional** — if you don't configure the secrets below, the workflow won't run and you can continue deploying manually with `make deploy`.

## What It Does

- Triggered by changes to `openclaw.json`, `docker/`, `docker-compose.yml`, `ansible/`, or `secrets/.env.enc`
- Connects to the VPS via an ephemeral Tailscale node (no public SSH required)
- Decrypts `secrets/.env.enc` using SOPS + age key from GitHub Secrets
- If `docker/` or `docker-compose.yml` changed: runs `make deploy REBUILD=1`
- Otherwise: runs `make deploy`

A manual **rollback workflow** is also included (`.github/workflows/rollback.yml`) — trigger it from the GitHub Actions UI with any previous git SHA. It also decrypts secrets with SOPS before deploying.

## One-Time Setup

**1. Generate a dedicated CI deploy SSH key**

```bash
ssh-keygen -t ed25519 -C "ci-deploy@openclaw" -f ci-deploy-key -N ""

# Authorize on the VPS
ssh openclaw@<VPS_IP> 'cat >> ~/.ssh/authorized_keys' < ci-deploy-key.pub

# Copy the private key — you'll add it as a GitHub Secret
cat ci-deploy-key

# Clean up — never commit the private key
rm ci-deploy-key ci-deploy-key.pub
```

**2. Create a Tailscale OAuth client**

Full reference: [Tailscale CI/CD guide](https://tailscale.com/docs/solutions/connect-github-CICD-workflows-to-private-infrastructure-without-public-exposure)

1. Tailscale admin → **Settings → OAuth clients** → Create new client
2. Required scopes: **Devices → Write** and **Auth keys → Write** (both required — Devices Write alone causes a 403)
3. Assign tag: `tag:ci-runner`
4. Save **Client ID** and **Client Secret**

**3. Tag the VPS in Tailscale**

Tailscale admin → **Machines** → your VPS → **Tags** → add `tag:openclaw-vps`.

**4. Set up SOPS encryption**

```bash
# Generate age key
make secrets-generate-key

# Encrypt your .env file
make secrets-encrypt

# Add the public key to .sops.yaml (shown after generation)
# Commit the encrypted file
git add secrets/.env.enc .sops.yaml
git commit -m "chore: add SOPS-encrypted secrets"
```

**5. Add GitHub repository secrets** (Settings → Secrets and variables → Actions → Repository secrets):

| Secret | Value |
|--------|-------|
| `TAILSCALE_OAUTH_CLIENT_ID` | From step 2 |
| `TAILSCALE_OAUTH_CLIENT_SECRET` | From step 2 |
| `SSH_PRIVATE_KEY` | Private key from step 1 |
| `VPS_TAILSCALE_HOSTNAME` | Tailscale **IP** of the VPS (e.g. `100.x.x.x`) — use the IP, not the MagicDNS hostname (MagicDNS resolution is unreliable on ephemeral runners) |
| `SOPS_AGE_KEY` | Full content of `secrets/age-key.txt` (the age private key — multiline is fine) |

## Updating Secrets

When you need to change environment variables:

```bash
# Edit the encrypted file (opens $EDITOR with decrypted content)
make secrets-edit

# Or manually:
make secrets-decrypt   # → secrets/.env
# ... edit secrets/.env ...
make secrets-encrypt   # → secrets/.env.enc

# Commit and push — CI will auto-deploy with the new secrets
git add secrets/.env.enc
git commit -m "chore: update environment secrets"
git push
```

## Verification

1. Push a change to `openclaw.json` → confirm the `Deploy to VPS` workflow triggers and completes
2. Push a change to `docker/Dockerfile` → confirm the rebuild step runs
3. Push a change to `secrets/.env.enc` → confirm the decrypt step works and deploy succeeds
4. Trigger `Rollback deployment` from the GitHub Actions UI with a previous SHA → confirm the VPS reverts
