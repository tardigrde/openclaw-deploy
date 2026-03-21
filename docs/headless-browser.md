# Headless Browser

The stack includes a `chromium` container (`chromedp/headless-shell`) so OpenClaw can use the browser tool on the VPS — useful for scraping JS-heavy or paywalled pages via the `agent-browser` skill.

## How It Works

Chrome's CDP endpoint rejects WebSocket connections where the `Host` header is not an IP address or `localhost` (DNS rebinding protection). To work around this without a proxy, the `chromium` service is assigned a static IP (`172.20.0.10`) on a custom Docker bridge subnet (`172.20.0.0/24`). OpenClaw connects directly to `http://172.20.0.10:9222` — Chrome accepts IP addresses unconditionally.

The `openclaw.json` browser profile:

```json
"browser": {
  "profiles": {
    "vps": {
      "cdpUrl": "http://172.20.0.10:9222",
      "color": "#00AA00"
    }
  }
}
```

## Verifying the Connection

```bash
make exec CMD="curl -s http://172.20.0.10:9222/json/version"
```

**If that fails** (shouldn't happen unless services are added/removed and the network is recreated), find the new IP:

```bash
make ssh
docker inspect openclaw-chromium-1 | grep IPAddress
```

Update `cdpUrl` in `openclaw.json` and run `make deploy`.
