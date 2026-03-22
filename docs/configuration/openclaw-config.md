---
title: "OpenClaw Configuration"
weight: 10
---
# OpenClaw Configuration

## Overview

Configuration lives in `openclaw.json` (gitignored — create from `openclaw.example.json`) and is deployed via `make deploy`.

## Agent Defaults

| Key | Value | Purpose |
|-----|-------|---------|
| `userTimezone` | `UTC` | Proper time context for scheduling, logs, heartbeat |
| `timeFormat` | `24` | European 24h format |
| `imageMaxDimensionPx` | `800` | Downscale images before vision API — saves ~30% tokens |
| `contextTokens` | `180000` | Safety margin below 200k model limit |

## Telegram Channel

### Retry Logic
Resilience for transient network errors (outbound `sendMessage`, `editMessage`, `sendChatAction`):
```json
"retry": {
  "attempts": 3,
  "minDelayMs": 400,
  "maxDelayMs": 30000,
  "jitter": 0.1
}
```

### Access Control
- **DM policy:** `pairing` (default) + `allowFrom` restriction
- **`allowFrom`:** `["<YOUR_TELEGRAM_ID>"]` — restricts DM access (extra layer beyond pairing)
- **`groupAllowFrom`:** `["<USER_ID_1>", "<USER_ID_2>"]` — global group sender restriction

**Security model:**
- DM pairing approvals apply to DM access only
- Group sender authorization is explicit (does NOT inherit DM pairing)
- `groupAllowFrom` is global fallback; per-group `allowFrom` overrides

### Groups
```json
"groups": {
  "*": { "requireMention": true },
  "<YOUR_GROUP_ID>": {
    "requireMention": false,
    "groupPolicy": "open",
    "systemPrompt": "You're in a group chat..."
  }
}
```

- `"*"` = all other groups require @mention (default behavior)
- Specific group (`<YOUR_GROUP_ID>`) = no mention needed, any member can trigger
- **Session key:** `agent:main:telegram:group:<YOUR_GROUP_ID>` (separate from DM)
- Group has separate conversation history from DM
- No heartbeat in groups (avoids noise)
- Shared workspace/memory (both sessions access same files)

### Mention Patterns
Added to `agents.list[].groupChat.mentionPatterns` for fallback detection:
```json
"mentionPatterns": ["@your_bot_username", "bot"]
```
These are case-insensitive regexes. Native Telegram @-mentions still work; patterns are a safety net.

### Privacy Mode
**Required:** Bot must have privacy mode disabled in BotFather for group messages without @mention.
1. `/setprivacy` → Disable in BotFather
2. Remove + re-add bot to group for change to take effect

## Commands & Permissions

```json
"commands": {
  "native": "auto",
  "nativeSkills": "auto",
  "bash": true,
  "config": true,
  "debug": true
},
"tools": {
  "elevated": {
    "enabled": true,
    "allowFrom": {
      "telegram": ["<YOUR_TELEGRAM_ID>"]
    }
  }
}
```

- `bash`, `config`, `debug` commands enabled for troubleshooting
- Only authorized users (via `allowFrom`) can use elevated/exec commands

## Session Architecture

| Chat | Session Key | Heartbeat | Scope |
|------|-------------|-----------|-------|
| DM | `agent:main:main` | Yes | Private |
| Group | `agent:main:telegram:group:<YOUR_GROUP_ID>` | No | Shared |

- **Separate context:** Group can't see DM history, DM can't see group history
- **Shared brain:** Same workspace, same memory files
- **No heartbeat in groups** — avoids noisy broadcasts

## Troubleshooting

### Polling Stall
Telegram long-polling may stall (`no getUpdates for N seconds`). Auto-recovers after restart.
```bash
openclaw gateway restart
```

### Network Errors
If you see `sendMessage failed: Network request failed`, check:
1. Outbound DNS/HTTPS to `api.telegram.org`
2. IPv6 issues — current config uses `dnsResultOrder: ipv4first` (default Node 22+)
3. Proxy if needed: `channels.telegram.proxy`

### Rate Limits
Anthropic API rate limits (429) trigger automatic fallback to configured model fallbacks. No action needed unless persistent — if 429s continue, check your `agents.defaults.model.fallbacks` chain in `openclaw.json`, or switch to a different provider (e.g. OpenRouter) via `OPENROUTER_API_KEY`.

## Future Considerations

- `pdfModel` for dedicated PDF handling
- `compaction.memoryFlush` to store memories before compaction
- `contextPruning` with cache-ttl mode (30m)
- `thinkingDefault: "low"` for cost optimization
- `timeoutSeconds: 300` for faster failure detection
- Multi-channel support (Discord, WhatsApp)
- Sandbox mode for group isolation if untrusted members added
