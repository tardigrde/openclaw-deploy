---
title: "ACP + Claude Code"
weight: 20
---
# ACP + Claude Code

Use Claude Code (and other AI coding harnesses) from your messaging platform — no SSH required. Runs inside the Gateway container via [ACP (Agent Client Protocol)](https://agentclientprotocol.com/).

## Architecture

```
Telegram/Discord → Clawdy (Gateway) → ACP runtime → acpx → Claude Code CLI
```

You send a message like _"review this PR with Claude Code"_ and Clawdy spawns an ACP session. Claude Code does the work, results stream back to your chat.

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

### 1. Quick install (no rebuild)

Install acpx and Claude Code into the running container, patch config, restart:

```bash
# Add to Makefile.local:
# addon-acp: @$(ANSIBLE) $(PLAYBOOK) --tags addon-acp

make addon-acp
```

This is idempotent — running it again skips if acpx is already installed.

### 2. Permanent install (across Docker rebuilds)

Add the packages to the npm install line in your `docker/Dockerfile`:

```dockerfile
ARG OPENCLAW_VERSION=2026.3.22
ARG ACPX_VERSION=0.3.1
ARG CLAUDE_CODE_VERSION=2.1.81
RUN npm install -g \
    openclaw@${OPENCLAW_VERSION} \
    clawhub \
    @steipete/summarize \
    ws \
    acpx@${ACPX_VERSION} \
    @anthropic-ai/claude-code@${CLAUDE_CODE_VERSION} \
```

Then rebuild:

```bash
make deploy REBUILD=1
```

After the rebuild, the addon-acp Ansible task can still be used to patch config if needed.

## Usage

### Persistent session (recommended)

Start a long-lived session in a Telegram thread or Discord channel:

```
/acp spawn claude --mode persistent --thread auto
```

Follow-up messages in the same thread go to the same Claude Code session.

### One-shot handoff

Tell Clawdy directly:

```
use Claude Code to review the changes in this PR
```

Clawdy spawns a session, runs the task, and reports back.

### From another agent

Clawdy can spawn ACP sessions via the `sessions_spawn` tool:

```
runtime: "acp", agentId: "claude", mode: "run"
```

## Config

The addon patches `openclaw.json` with:

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

### Permissions

| Setting | Value | Why |
|---------|-------|-----|
| `permissionMode` | `approve-all` | No TTY in ACP sessions — interactive approval doesn't work |
| `nonInteractivePermissions` | `deny` | Graceful degradation instead of crashing on permission prompts |

To tighten permissions for production, change `permissionMode` to `approve-reads` (auto-approve reads, ask before writes). Note: this only works if someone is watching the session to approve.

### Session TTL

`runtime.ttlMinutes: 120` — sessions expire after 2 hours of inactivity. Adjust based on your workflow. Set higher for long-running coding tasks.

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

- **"acpx: not found"** — addon wasn't installed or container was rebuilt. Run `make addon-acp` again.
- **Claude Code crashes on file write** — `permissionMode` might be too restrictive. Check it's set to `approve-all`.
- **Session doesn't persist across messages** — make sure you're using `--thread auto` or staying in the same Telegram thread/Discord channel.
- **"ANTHROPIC_API_KEY not set"** — add it with `make secrets-edit` then `make deploy`.
