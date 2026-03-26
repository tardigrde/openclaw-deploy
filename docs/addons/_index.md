---
title: "Add-ons"
weight: 6
---

Add-ons are optional features that extend the base deployment. They are installed via `Makefile.local` targets and local scripts — none are active by default.

Add-on scripts live in `scripts/local/` (gitignored, copy from `scripts/local.example/`). The corresponding make targets are defined in `Makefile.local` (copy from `Makefile.local.example`).

## Available Add-ons

| Add-on | Make target | Doc |
|--------|-------------|-----|
| Morning weather report | `make addon-weather` | [Weather Report](/addons/weather-report/) |
| ACP + Claude Code | `make deploy REBUILD=1` | [ACP + Claude Code](/addons/acp-claude-code/) |
