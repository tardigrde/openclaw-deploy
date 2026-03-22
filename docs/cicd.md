---
title: "CI/CD Setup"
weight: 90
---
# CI/CD

The built-in CI runs **Terraform only** (`plan` on PRs, `apply` on manual dispatch). Ansible is never run in CI — all `make bootstrap` / `make deploy` operations are local only.

An optional GitOps deployment workflow is also included — copy `.github/workflows/deploy.yml.example` to `.github/workflows/deploy.yml` to enable automatic Ansible-based deployments on push. See [GitOps auto-deploy](gitops-auto-deploy.md) for setup instructions.

## Terraform Plan (automatic on PRs)

When a pull request touches `terraform/**`, the `Terraform Plan` workflow runs automatically and posts the plan diff as a PR comment.

## Terraform Apply (manual)

`terraform apply` is triggered manually after merging:

1. Go to **Actions** → **Terraform Apply** → **Run workflow**
2. Select the branch and click **Run workflow**

The apply workflow uses a `production` environment — you can configure approval gates in **Settings** → **Environments** → **production**.

## Required GitHub Variables

Set these in **Settings** → **Variables and secrets** → **Actions** → **Variables** (not secrets — WIF is keyless):

| Variable | Value |
| -------- | ----- |
| `GCP_WIF_PROVIDER` | Full resource name of the WIF provider (output from `my-gcp-project`, e.g. `projects/<proj-number>/locations/global/workloadIdentityPools/github/providers/github`) |
| `GCP_SERVICE_ACCOUNT` | Automation SA email (e.g. `automation@<project>.iam.gserviceaccount.com`) |

## Required GitHub Secrets

These are for the **Terraform CI workflows only**:

| Secret | Description |
| ------ | ----------- |
| `HCLOUD_TOKEN` | Hetzner Cloud API token |
| `SSH_KEY_FINGERPRINT` | SSH key fingerprint registered in Hetzner |

> The optional GitOps deployment workflow requires additional secrets (`SSH_PRIVATE_KEY`, `SOPS_AGE_KEY`, and optionally Tailscale OAuth credentials). See [GitOps auto-deploy](gitops-auto-deploy.md).
