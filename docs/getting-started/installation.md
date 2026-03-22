---
title: "Installation"
weight: 10
---

## Prerequisites

1. **Terraform** >= 1.5 ([install](https://developer.hashicorp.com/terraform/install))
2. **Ansible** ([install](https://docs.ansible.com/projects/ansible/latest/installation_guide/intro_installation.html))
3. **age** and **sops** — required for secret encryption (`make secrets-encrypt`). Install via your package manager or [age releases](https://github.com/FiloSottile/age/releases) / [sops releases](https://github.com/getsops/sops/releases).
4. **jq** — required for `make validate`. Install via your package manager.
5. **Hetzner Cloud account** with API token ([console](https://console.hetzner.cloud/))
6. **SSH key** uploaded to Hetzner Cloud. Default path: `~/.ssh/id_rsa`. Override with `SSH_KEY` env var.
7. *(Optional)* **Remote Terraform state** — the default is local (no setup needed). For GCS or other remote backends, see [Remote State Backend](/operations/remote-state/).

## 1. Clone

```bash
git clone https://github.com/tardigrde/openclaw-deploy.git
cd openclaw-deploy
```

## 2. Configure infrastructure secrets

```bash
cp secrets/inputs.example.sh secrets/inputs.sh
vim secrets/inputs.sh
```

Required: `HCLOUD_TOKEN`, `TF_VAR_ssh_key_fingerprint` (from [Hetzner Console](https://console.hetzner.cloud/) → Security → SSH Keys). See [Secrets Reference](/configuration/secrets/) for the full variable reference and Tailscale-specific notes.

## 3. Configure OpenClaw

```bash
cp openclaw.example.json openclaw.json
vim openclaw.json
```

Customize: Telegram IDs, timezone, AI models. See the official [OpenClaw configuration docs](https://docs.openclaw.ai/gateway/configuration-reference) for details on every option.

> **Tailscale users:** Skip the `allowedOrigins` Tailscale hostname for now — you won't know it until after bootstrap. You'll fill it in at the Tailscale setup step.

## 4. Configure Terraform backend

```bash
cp terraform/envs/prod/backend.tf.example terraform/envs/prod/backend.tf
```

The default (`backend "local"`) requires no setup. To use GCS remote state instead, edit `backend.tf` — see [Remote State Backend](/operations/remote-state/).

## Next Step

Continue to **[Deployment & Bootstrap](/getting-started/bootstrap/)** to provision the VPS and start containers.
