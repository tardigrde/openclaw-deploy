---
title: "Agents & Sessions"
weight: 10
aliases: ["/agents/"]
---
# Agents

OpenClaw supports multiple isolated agents, each with their own workspace and model. Define them in `openclaw.json` under `agents.list`.

## Adding an Agent

```json
{
  "agents": {
    "list": [
      {
        "id": "main",
        "workspace": "~/.openclaw/workspace",
        "default": true
      },
      {
        "id": "researcher",
        "workspace": "~/.openclaw/workspace-researcher",
        "model": "anthropic/claude-haiku-4-5"
      }
    ]
  }
}
```

Then deploy:

```bash
make deploy
```

Each agent gets its own isolated workspace directory on the VPS. Seed files into `docker/workspace-templates/` to populate the main workspace on first start (no-clobber — existing files are never overwritten).

## Exec Approvals

OpenClaw exec approvals use a two-part system:

1. **Policy** — `ask=off, security=full` set in `openclaw.json`
2. **Socket daemon** — started by `entrypoint.sh` via `openclaw node run` before the gateway

Without the daemon, the gateway falls back to broadcasting approval requests to WebSocket clients, which time out after 120s. `ask=off` in the config has no effect without the daemon running.

**If execs are still requiring approval after a fresh deploy:**

```bash
# Verify policy is loaded
make exec CMD="openclaw approvals get"
# Expected: Defaults | security=full, ask=off

# Verify socket exists
make exec CMD="ls -la /home/node/.openclaw/exec-approvals.sock"
# If missing, check container logs:
make logs
```
