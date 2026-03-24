---
title: "Private Fork"
weight: 4
---

For a long-lived production setup, the recommended pattern is a **private fork** — tracking this repo as `upstream` and keeping credentials, personal config, and extensions in your fork. This lets you pull upstream improvements with minimal friction while keeping your private files out of the public repo.

## Repo layout

| Repo | Purpose |
|------|---------|
| `openclaw-deploy` (this repo) | Public template — source of truth for all shared files |
| `your-private-fork` | Your production deployment — credentials, overrides, extensions |

All shared infrastructure changes should be made in `openclaw-deploy` first, then pulled into your fork — never the reverse.

## One-time setup

### 1. Create your private fork

Create a private repo on GitHub (or any host), then clone it and add this repo as `upstream`:

```bash
git clone git@github.com:you/openclaw-prod.git
cd openclaw-prod
git remote add upstream https://github.com/tardigrde/openclaw-deploy.git
git fetch upstream
git merge upstream/main
```

### 2. Register custom merge drivers

These are stored in `.git/config` (not committed) and must be set once per clone:

```bash
git config merge.theirs.name "always take theirs"
git config merge.theirs.driver "cp %B %A"
git config merge.ours.name "always keep ours"
git config merge.ours.driver "true"
```

- `merge=theirs` — upstream wins; used for almost all shared files
- `merge=ours` — your fork wins; used for files you extend (e.g. a Tailscale serve config with extra ports)
- `merge=union` — keeps lines from both sides; used for `.gitignore` and `.gitattributes`

### 3. Add a `.gitattributes`

Tell git which driver to use for each file. Copy and adapt:

```gitattributes
# Shared files — upstream always wins
CLAUDE.md                                    merge=theirs
README.md                                    merge=theirs
SECURITY.md                                  merge=theirs
LICENSE                                      merge=theirs
Makefile                                     merge=theirs
Makefile.local.example                       merge=theirs
docker-compose.yml                           merge=theirs
docker-compose.override.example.yml          merge=theirs
docker/Dockerfile                            merge=theirs
docker/entrypoint.sh                         merge=theirs
docker/**                                    merge=theirs
ansible/plays/**                             merge=theirs
ansible/templates/**                         merge=theirs
ansible/ansible.cfg                          merge=theirs
ansible/site.yml                             merge=theirs
ansible/site.local.example.yml               merge=theirs
scripts/**                                   merge=theirs
docs/**                                      merge=theirs
terraform/modules/**                         merge=theirs
terraform/envs/prod/main.tf                  merge=theirs
terraform/envs/prod/variables.tf             merge=theirs
terraform/envs/prod/backend.tf.example       merge=theirs
terraform/envs/prod/terraform.tfvars.example merge=theirs
secrets/inputs.example.sh                    merge=theirs
secrets/.env.example                         merge=theirs
openclaw.example.json                        merge=theirs
.github/workflows/**                         merge=theirs
.githooks/**                                 merge=theirs
.sops.yaml                                   merge=theirs
go.mod                                       merge=theirs
go.sum                                       merge=theirs

# Files your fork extends — your version wins
ansible/templates/tailscale-serve.json.j2    merge=ours

# Both sides' rules kept
.gitignore                                   merge=union
.gitattributes                               merge=union
```

With these drivers in place, `git merge upstream/main` resolves nearly all files automatically.

## Pulling upstream changes

```bash
git fetch upstream
git merge upstream/main   # merge drivers resolve most files automatically
git push
```

If upstream release commits (e.g. `chore(release): x.y.z`) conflict, skip them:

```bash
git rebase --skip   # repeat for each release commit
```

## What lives where

### Upstream wins — always edit in `openclaw-deploy`, never directly in your fork

Makefile, docker-compose.yml, Dockerfile, all Ansible plays and templates, scripts, docs, Terraform modules, and example/template files.

### Your fork wins — files your fork extends beyond the upstream version

Any file where you add ports, services, or settings on top of the upstream version (e.g. a Tailscale serve config exposing additional ports).

### Union merge — both sides' lines are kept

`.gitignore` (your fork adds private-file rules) and `.gitattributes` (your fork extends the driver rules).

### Private-only — gitignored in `openclaw-deploy`, no conflict possible

`openclaw.json`, `docker-compose.override.yml`, `Makefile.local`, private Ansible plays (`*.local.yml`), `scripts/local/`, `secrets/`, Terraform backend and tfvars, CI workflows for your fork.

## Automating upstream syncs

If you use Claude Code, you can define a skill in your private fork that automates the fetch → merge → PR workflow. The skill can handle expected release-commit conflicts, check for unexpected conflicts, and open a clean PR — so pulling upstream becomes a single command.
