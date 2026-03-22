---
title: "Workspace Git Sync"
weight: 80
---
# Workspace Git Sync

Back up `~/.openclaw/workspace` to a private GitHub repo automatically. Runs as a native cron job on the VPS, pushing to a configurable branch (default: `auto`).

## Setup

Add to `secrets/.env`:

```
GIT_WORKSPACE_REPO=your-username/openclaw-workspace
GIT_WORKSPACE_BRANCH=auto
GIT_WORKSPACE_TOKEN=ghp_your_personal_access_token
GIT_WORKSPACE_SYNC_SCHEDULE=0 4 * * *
```

The cron job auto-enables when `GIT_WORKSPACE_REPO` is set. Deploy with `make deploy`.

## Operations

```bash
# Trigger sync immediately
make workspace-sync

# Disable: remove or clear GIT_WORKSPACE_REPO from .env and redeploy
make deploy
```

## Logs

The cron job writes to `~/openclaw/logs/workspace-sync.log` on the VPS:

```bash
ssh openclaw@<server> 'tail -f ~/openclaw/logs/workspace-sync.log'
```
