---
title: "Headless Browser"
weight: 40
aliases: ["/headless-browser/"]
---
# Headless Browser

OpenClaw includes a built-in browser powered by [agent-browser](https://github.com/nicedoc/agent-browser) running inside the gateway container. Chromium and its dependencies are installed at Docker build time via `agent-browser install --with-deps`.

No sidecar container is needed — the browser runs in-process within the OpenClaw gateway.

## How It Works

The `agent-browser` npm package manages a local Chromium installation and exposes browser automation capabilities to OpenClaw skills. The gateway configures it automatically.

## Verifying the Installation

```bash
make exec CMD="npx agent-browser --version"
```

The browser is ready when the gateway logs show `agent-browser` initialization complete.
