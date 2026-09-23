---
title: "Portals"
weight: 40
---
# Portals (Control UI → Portals)

Portals proxy an agent-run development server to the operator's browser. The agent runs `portal open` for the app's port, starts the server with `PORT`/`PUBLIC_URL` from the result, and the operator opens it from **Control UI → Portals**. See the OpenClaw reference: `portal` tool docs (`docs/gateway/portals.md` in the OpenClaw package).

## Docker + Tailscale Serve limitation

In this deployment portals **do not work out of the box**:

1. The gateway allocates each portal listener on an **ephemeral random port** (`port: 0` in the gateway source) **inside the gateway container's** network namespace.
2. `docker-compose.yml` publishes only `18789` to the host, so the portal listener port is container-internal.
3. Tailscale Serve proxies **host loopback ports only**, so it can never reach the container-internal listener.

Symptom: the portal opens fine (`portal.list` succeeds), but Control UI shows **"not reachable from this browser"** with retry guidance, or an empty/dead iframe. The bundled OpenClaw docs call this out under Troubleshooting: *"A proxy or tunnel in front of the Gateway does not automatically expose portal listener ports."*

## Diagnose

Run on the VPS host (or via `make exec CMD=...` where noted):

```bash
# 1. Portals exist? (in container)
docker exec $(docker ps -q -f label=com.docker.compose.service=openclaw-gateway) \
  openclaw gateway call portal.list
# Note the listenPort — it is random per portal (e.g. 46799), NOT the app port.

# 2. Portal proxy reachable from host via the container bridge IP?
CID=$(docker ps -q -f label=com.docker.compose.service=openclaw-gateway)
BRIDGE=$(docker inspect $CID --format '{{range $k,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}')
curl -s -o /dev/null -w "%{http_code}\n" "http://$BRIDGE:<listenPort>/?openclaw_portal=<token>"
# 502 = proxy reachable, app not listening yet (normal before the dev server starts)
# 200 = proxy reachable and app serving
# 000/timeout = host cannot reach the portal listener at all

# 3. What did the latest session actually do? (DB, not just container logs)
python3 -c "
import sqlite3, datetime
db = '/home/openclaw/.openclaw/state/openclaw.sqlite'
con = sqlite3.connect(f'file:{db}?mode=ro', uri=True)
con.row_factory = sqlite3.Row
for r in con.execute(
    \"SELECT occurred_at, kind, action, status, tool_name FROM audit_events \"
    \"WHERE session_key='agent:main:telegram:group:<id>:topic:<n>' \"
    'ORDER BY sequence DESC LIMIT 20'):
    ts = datetime.datetime.fromtimestamp(r['occurred_at']/1000, tz=datetime.timezone.utc).strftime('%H:%M:%S')
    print(ts, r['kind'], r['action'], r['status'], r['tool_name'])
"
```

If step 2 returns 502/200, the portal itself is healthy — only the browser path is missing. Use the bridge below.

## Fix: portal bridge

`scripts/portal-bridge.sh` (via make) forwards a portal to the tailnet:

```bash
make portal-status                          # list portals + active bridges
make portal-bridge PORTAL=p8765             # bridge portal p8765 (-> :<target-port> on tailnet)
make portal-bridge PORTAL=p8765 PORT=8091   # ...or pick a free host port explicitly
make portal-bridge-stop PORT=8765           # tear down forwarder + serve proxy
```

Then open `https://<node>.<tailnet>.ts.net:<PORT>/?openclaw_portal=<token>`, using the token query from the agent's `portal.open` result. Auth is still enforced by the gateway portal proxy; the bridge only moves bytes (host `127.0.0.1:<PORT>` → container `<bridge-ip>:<listenPort>` via a `screen` session, plus `tailscale serve --https`).

For a **persistent** bridge, add the stable port to `ansible/templates/tailscale-serve.json.j2` (`"${TS_CERT_DOMAIN}:<PORT>"` → `Proxy http://127.0.0.1:<PORT>`) and `make deploy` — imperative `tailscale serve --bg` entries are reset on the next deploy.

## Limitations

- Portal listeners (and their tokens) **die on gateway restart**. Re-run `portal.open`, then `make portal-bridge` with the new id.
- The bridge's stable host `PORT` must be free (fails fast otherwise).
- Quick workaround without portals: serve files directly on the host (`python3 -m http.server`) and expose via `tailscale serve --https` — see the `vps-share` skill. This bypasses portal auth; prefer the bridge for agent-run apps.
