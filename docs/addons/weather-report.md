---
title: "Weather Report"
weight: 150
---
# Morning Weather Report

A lightweight daily weather summary sent to Telegram each morning. Uses `wttr.in` and the Telegram Bot API — no LLM involved, zero token cost.

**Format:**

```
Good morning! 2026-03-05, Wednesday
Now: 8°C (feels like 5°C)
Max: 12°C / Min: 3°C | Rain: 40% (2.4 mm)
```

Rain line only appears when chance >= 20%.

## Setup

Add to `secrets/.env`:

```
TELEGRAM_BOT_TOKEN=your-bot-token
TELEGRAM_CHAT_ID=your-chat-id
```

Then install the cron job on the VPS:

```bash
make addon-weather
```

This copies `scripts/local/morning-weather.py` to the VPS and registers a host cron entry (copy `scripts/local.example/morning-weather.py` to `scripts/local/morning-weather.py` first — `scripts/local/` is gitignored for personal customization) (`0 5 * * *` UTC). Adjust the hour in the Ansible task to match your timezone. Credentials are sourced from `~/openclaw/.env` at runtime.

## Test

```bash
make ssh
~/run-morning-weather.sh
```

**Logs:** `~/logs/morning-weather.log` on the VPS.

> **Note:** If you have a `morning-weather` cron job configured in OpenClaw, you can remove it once this is working — this host-level cron replaces it.
