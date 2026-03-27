---
title: "Getting Started"
weight: 1
---

Infrastructure-as-code for deploying [OpenClaw](https://openclaw.ai) on a Hetzner Cloud VPS inside Docker.

- Terraform provisions the VPS and firewall
- Ansible handles all deployment tasks — idempotent, dry-run capable, single command for every scenario (runs locally only, never in CI)
- Docker Compose runs OpenClaw gateway + headless Chromium on the VPS
- All day-to-day operations go through `make`

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

## Next Steps

1. **[Installation](/getting-started/installation/)** — install prerequisites, clone the repo, and configure secrets and Terraform
2. **[Deployment & Bootstrap](/getting-started/bootstrap/)** — provision the VPS, bootstrap containers, and verify the deployment
