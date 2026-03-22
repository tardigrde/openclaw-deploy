---
title: "Skills & Tools"
weight: 60
---
# Skills

OpenClaw is extended via skills — slash commands, hooks, templates, and tool definitions. `docker/skills-manifest.txt` lists which skills are auto-installed at container startup via `clawhub install`.

## Adding a ClawHub Skill

[ClawHub](https://clawhub.ai/) is the community skill registry.

1. Find the skill at [clawhub.ai](https://clawhub.ai/) (e.g. `pdf`, `jira`)
2. Add it to `docker/skills-manifest.txt`:

   ```
   pdf
   ```

3. Rebuild and deploy (the manifest is baked into the image):

   ```bash
   make deploy REBUILD=1
   ```

## Included Skills

| Skill | Description |
|-------|-------------|
| `yt` | YouTube transcript fetching and video search |
| `agent-browser` | Headless browser for JS-heavy/paywalled pages |
| `system-monitor` | CPU/RAM/GPU status check |
| `conventional-commits` | Format commit messages per convention |
| `github` | GitHub issues, PRs, CI runs via gh CLI |
| `summarize` | Summarize URLs, PDFs, images, audio, YouTube |
| `weather` | Weather lookup |
