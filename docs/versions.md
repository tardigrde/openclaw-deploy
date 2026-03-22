---
title: "Version Management"
weight: 30
---
# Version Management

All dependencies are pinned in their respective config files. Renovate Bot opens
weekly PRs when updates are available (see `renovate.json`).

## Where versions live

| Dependency | File | Notes |
|---|---|---|
| OpenClaw | `docker/Dockerfile` (`ARG OPENCLAW_VERSION`) | Never auto-merged — check release notes + run `make backup-now` first |
| Node.js base image | `docker/Dockerfile` (`FROM node:...`) | |
| chromedp/headless-shell | `docker-compose.yml` (`image:`) | |
| Terraform CLI | `terraform/envs/prod/main.tf` (`required_version`) | Also enforced in CI via `hashicorp/setup-terraform` input |
| hcloud provider | `terraform/envs/prod/main.tf` (`version =`) | |
| ansible-core | `.github/workflows/*.yml` (`pip install`) | Range constraint — bump minor manually |
| GitHub Actions | `.github/workflows/*.yml` (`uses:`) | Auto-merged by Renovate |

## Auto-update policy

Renovate runs weekly and opens PRs grouped by ecosystem:

- **GitHub Actions** — auto-merged (low risk)
- **Everything else** — manual review required

To activate Renovate on the repo: install the
[Renovate GitHub App](https://github.com/apps/renovate) and grant it access to
this repository.
