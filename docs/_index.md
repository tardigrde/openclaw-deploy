---
title: "OpenClaw Deploy"
---

Infrastructure-as-code for deploying [OpenClaw](https://openclaw.ai) on a Hetzner Cloud VPS inside Docker. Terraform provisions the VPS, Ansible handles deployment, Docker Compose runs the services — all driven by `make`.

| Section | What's inside |
|---------|---------------|
| [Getting Started](/getting-started/) | Prerequisites, installation, first deploy |
| [Configuration](/configuration/) | OpenClaw config, secrets, version pinning |
| [Guides](/guides/) | Skills, headless browser, agents, workspace sync, lossless context |
| [Operations](/operations/) | Make targets reference, update/backup/restore workflows |
| [Security](/security/) | Firewall, SSH hardening, SOPS encryption, fail2ban |
| [Add-ons](/addons/) | Optional extensions (morning weather report, …) |
