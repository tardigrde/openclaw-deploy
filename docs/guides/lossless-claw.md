---
title: "Lossless Context"
weight: 50
---
# lossless-claw — Lossless Context Management

## What

[lossless-claw](https://github.com/Martian-Engineering/lossless-claw) is an OpenClaw plugin that replaces the built-in sliding-window compaction with a DAG-based summarization system. Instead of truncating older messages when context fills up, it:

1. **Persists every message** in a SQLite database
2. **Summarizes chunks** of older messages into compressed nodes
3. **Condenses summaries** into higher-level nodes as they accumulate (forming a DAG)
4. **Assembles context** each turn by combining summaries + recent raw messages
5. **Provides agent tools** (`lcm_grep`, `lcm_describe`, `lcm_expand`) so the agent can search and recall details from compacted history

## Why we install it

**The problem:** Without LCM, OpenClaw's default compaction simply drops older messages when context fills up. In long conversations (multi-hour sessions, daily check-ins), context gets lost — the agent forgets decisions made hours or days ago.

**The solution:** LCM ensures nothing is ever lost. The agent can drill into any summary to recover original details. For a personal assistant that needs to remember ongoing projects, house hunting progress, business decisions — this is critical.

**In practice:** The difference between "my AI forgot what we discussed yesterday" and "my AI remembers everything." Essential for long sessions, daily check-ins, or any workflow where continuity across conversations matters.

**Cost:** Minimal. Summarization uses Anthropic Haiku (~$0.001-0.003 per compaction pass). For typical usage, adds ~€1-5/month. Configured via `LCM_SUMMARY_MODEL` to use a cheap model, not the main conversation model.

## Configuration

### openclaw.json

```json
{
  "plugins": {
    "entries": {
      "lossless-claw": {
        "enabled": true,
        "config": {
          "freshTailCount": 32,
          "contextThreshold": 0.75,
          "incrementalMaxDepth": -1
        }
      }
    },
    "slots": {
      "contextEngine": "lossless-claw"
    }
  }
}
```

### Key settings explained

| Setting | Value | Why |
|---|---|---|
| `freshTailCount` | 32 | Protects last 32 messages from compaction — enough recent context for continuity |
| `contextThreshold` | 0.75 | Triggers compaction at 75% of context window — leaves headroom for responses |
| `incrementalMaxDepth` | -1 | Unlimited DAG depth — summaries cascade as deep as needed automatically |
| `LCM_SUMMARY_MODEL` (env) | `anthropic/claude-haiku-4-5` | Direct Anthropic API (not OpenRouter) — cheapest option for summarization. Set in `.env`. |

## Installation

The plugin is installed automatically via the Docker entrypoint script on every container start. It is **enabled by default** — no action needed to opt in.

To disable it, set `INSTALL_LOSSLESS_CLAW=0` in `secrets/.env`:

```bash
INSTALL_LOSSLESS_CLAW=0
```

Then redeploy: `make deploy REBUILD=1`.

Installation is idempotent — safe to run repeatedly. No Dockerfile changes needed.

## References

- [GitHub repo](https://github.com/Martian-Engineering/lossless-claw)
- [Animated visualization](https://losslesscontext.ai)
- [LCM paper](https://papers.voltropy.com/LCM)
- [Configuration guide](https://github.com/Martian-Engineering/lossless-claw/blob/main/docs/configuration.md)
