---
title: "Sandbox Configuration"
weight: 15
aliases: ["/sandboxing/"]
---

# Sandbox Configuration Guide

This guide explains how to enable agent sandboxing in OpenClaw. Sandboxing isolates tool execution from the host system, providing an extra layer of security.

> **Note:** This guide is for the openclaw-deploy repository. For the full OpenClaw sandboxing documentation, see [Gateway Sandboxing](https://docs.openclaw.ai/gateway/sandboxing).

## Why Enable Sandboxing?

Without sandboxing, agent tool execution (file operations, shell commands) runs directly on your VPS. If the agent is compromised or makes a mistake, the blast radius is your entire server.

With sandboxing enabled, tools run in isolated containers or remote environments.

##Security Considerations

| Without Sandbox | With Sandbox |
|-----------------|--------------|
| Full host access | Isolated execution |
| Any file readable/writable | Restricted to sandbox workspace |
| Host secrets at risk | Secrets stay on host |

## Quick Start

To enable sandboxing, add this to your `openclaw.json`:

```jsonc
{
  "agents": {
    "defaults": {
      "sandbox": {
        "mode": "all",           // "off", "non-main", or "all"
        "scope": "session",      // "session", "agent", or "shared"
        "workspaceAccess": "none"  // "none", "ro", or "rw"
      }
    }
  }
}
```

### Mode Options

| Mode | Description |
|------|-------------|
| `"off"` | No sandboxing (default) |
| `"non-main"` | Sandbox non-main sessions only (good for dev) |
| `"all"` | Every session runs in sandbox (recommended for production) |

### Scope Options

| Scope | Description |
|-------|-------------|
| `"session"` | One container per session (default) |
| `"agent"` | One container per agent |
| `"shared"` | One container shared by all sessions |

### Workspace Access

| Access | Description |
|--------|-------------|
| `"none"` | Sandbox has isolated workspace (default, most secure) |
| `"ro"` | Agent workspace mounted read-only |
| `"rw"` | Agent workspace mounted read/write |

## Docker Sandbox Setup

Before using sandbox, build the sandbox image:

```bash
# On your VPS, run:
docker build -t openclaw-sandbox:bookworm-slim -f Dockerfile.sandbox scripts/sandbox/
# Or use the convenience script:
./scripts/sandbox-setup.sh
```

> **Note:** For the openclaw-deploy repo, the Dockerfile already includes the necessary sandbox setup. The sandbox image is built automatically when you `make deploy REBUILD=1`.

## Per-Agent Override

You can enable sandboxing for specific agents only:

```jsonc
{
  "agents": {
    "defaults": {
      "sandbox": { "mode": "off" }
    },
    "list": [
      {
        "id": "untrusted-code-review",
        "sandbox": {
          "mode": "all",
          "scope": "session"
        }
      }
    ]
  }
}
```

## Tool Policy with Sandbox

Tool policies still apply inside sandbox. To deny specific tools even in sandbox:

```jsonc
{
  "tools": {
    "deny": ["group:runtime", "group:automation"]
  }
}
```

## Elevated Exec (Bypasses Sandbox)

The `tools.elevated` setting allows certain users to run exec on the host, bypassing sandboxing. This is an escape hatch — use with caution:

```jsonc
{
  "tools": {
    "elevated": {
      "enabled": true,
      "allowFrom": {
        "telegram": ["<your-user-id>"]
      }
    }
  }
}
```

## Troubleshooting

### Sandbox container not starting

```bash
# Check sandbox status
docker ps -a | grep openclaw-sandbox

# Check logs
docker logs <container-id>
```

### Permission errors

Ensure your workspace directory is owned by the correct UID:

```bash
sudo chown -R 1000:1000 ~/.openclaw/workspace
```

## See Also

- [OpenClaw Sandboxing Docs](https://docs.openclaw.ai/gateway/sandboxing)
- [OpenClaw Security](https://docs.openclaw.ai/gateway/security)
- [OpenShell Backend](https://docs.openclaw.ai/gateway/openshell)