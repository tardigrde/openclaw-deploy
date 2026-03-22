---
title: "Configuration"
weight: 2
---

OpenClaw Deploy uses native override files at every layer — all gitignored so your local customizations never conflict with upstream changes.

## Override System

| Layer | What to customize | Override file | Template | Required? | Copy when |
|-------|-------------------|---------------|----------|-----------|-----------|
| Terraform | State backend | `terraform/envs/prod/backend.tf` | `backend.tf.example` | Required | Before `make init` |
| Terraform | Infrastructure variables | `terraform/envs/prod/terraform.tfvars` | `terraform.tfvars.example` | Required | Before `make plan` |
| Docker | Extra services | `docker-compose.override.yml` | `docker-compose.override.example.yml` | Optional | **Before `make bootstrap`** |
| Make | Extra targets | `Makefile.local` | `Makefile.local.example` | Optional | Anytime |
| Ansible | Extra plays | `ansible/site.local.yml` | `ansible/site.local.example.yml` | Optional | Anytime |
| Scripts | Addon scripts | `scripts/local/` | `scripts/local.example/` | Optional | Anytime |

**Docker Compose:** `docker-compose.override.yml` is automatically merged — no flags needed.

**Makefile:** `Makefile.local` is loaded via `-include`. All variables from the main Makefile are available.

**Ansible:** `ansible/site.local.yml` is used instead of `site.yml` when it exists. It should import `site.yml` first, then add your local plays.
