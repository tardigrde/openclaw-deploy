---
title: "ACP + Claude Code"
weight: 20
---
# ACP + Claude Code

Use Claude Code (and other AI coding harnesses) from your messaging platform — no SSH required. Runs inside the Gateway container via [ACP (Agent Client Protocol)](https://agentclientprotocol.com/).

## Architecture

```text
Telegram/Discord → OpenClaw Gateway → ACP runtime → acpx → Claude Code CLI
```

You send a message like _"review this PR with Claude Code"_ and OpenClaw spawns an ACP session. Claude Code does the work, results stream back to your chat.

## Supported Harnesses

| Harness | Command |
|---------|---------|
| Claude Code | `/acp spawn claude` (default) |
| OpenAI Codex | `/acp spawn codex` |
| Google Gemini | `/acp spawn gemini` |
| OpenCode | `/acp spawn opencode` |
| Pi | `/acp spawn pi` |
| Kimi | `/acp spawn kimi` |

## Prerequisites

- `ANTHROPIC_API_KEY` in `secrets/.env` (required for Claude Code)
- For other harnesses: their respective API keys

## Setup

ACP requires two things: the packages baked into the image, and config in `openclaw.json`. Both are managed through the normal deploy flow — no separate Ansible step needed.

### 1. Add packages to `docker/install-optional.sh`

In your private fork, edit `docker/install-optional.sh` and add:

```bash
npm install -g \
  acpx@0.3.1 \
  @anthropic-ai/claude-code@2.1.81
```

### 2. Add ACP config to `openclaw.json`

Add the following to your local `openclaw.json` (merge into existing keys as needed):

```json
{
  "acp": {
    "enabled": true,
    "dispatch": { "enabled": true },
    "backend": "acpx",
    "defaultAgent": "claude",
    "allowedAgents": ["claude", "codex", "pi", "opencode", "gemini", "kimi"],
    "maxConcurrentSessions": 4,
    "stream": {
      "coalesceIdleMs": 300,
      "maxChunkChars": 1200
    },
    "runtime": {
      "ttlMinutes": 120
    }
  },
  "plugins": {
    "entries": {
      "acpx": {
        "enabled": true,
        "config": {
          "permissionMode": "approve-all",
          "nonInteractivePermissions": "deny"
        }
      }
    }
  }
}
```

For subagent spawning, also add `"claude"` to your main agent's `subagents.allowAgents` list.

### 3. Deploy

```bash
make deploy REBUILD=1
```

This rebuilds the image with the new packages and pushes the updated config.

## Usage

### Persistent session (recommended)

Start a long-lived session in a Telegram thread or Discord channel:

```text
/acp spawn claude --mode persistent --thread auto
```

Follow-up messages in the same thread go to the same Claude Code session.

### One-shot handoff

Tell OpenClaw directly:

```text
use Claude Code to review the changes in this PR
```

OpenClaw spawns a session, runs the task, and reports back.

### From another agent

OpenClaw can spawn ACP sessions via the `sessions_spawn` tool:

```text
runtime: "acp", agentId: "claude", mode: "run"
```

## Config reference

### Permissions

| Setting | Value | Why |
|---------|-------|-----|
| `permissionMode` | `approve-all` | No TTY in ACP sessions — interactive approval doesn't work |
| `nonInteractivePermissions` | `deny` | Graceful degradation instead of crashing on permission prompts |

To tighten permissions, change `permissionMode` to `approve-reads` (auto-approve reads, ask before writes). This only works if someone is watching the session to approve write operations.

### Session TTL

`runtime.ttlMinutes: 120` — sessions expire after 2 hours of inactivity. Increase for long-running coding tasks.

## Troubleshooting

```bash
# Verify acpx is installed
docker compose exec openclaw-gateway acpx --version

# Verify Claude Code is installed
docker compose exec openclaw-gateway claude --version

# Check plugin is loaded
docker compose exec openclaw-gateway openclaw plugins list | grep acpx

# Check ACP config
docker compose exec openclaw-gateway cat /home/node/.openclaw/openclaw.json | jq .acp

# View ACP session logs
docker compose logs openclaw-gateway --tail 50 | grep -i acp
```

### Common issues

- **"acpx: not found"** — packages aren't in the image. Add them to `docker/install-optional.sh` and run `make deploy REBUILD=1`.
- **Claude Code crashes on file write** — check `permissionMode` is set to `approve-all` in `openclaw.json`.
- **Session doesn't persist across messages** — use `--thread auto` or stay in the same Telegram thread/Discord channel.
- **"ANTHROPIC_API_KEY not set"** — add it with `make secrets-edit` then `make deploy`.
