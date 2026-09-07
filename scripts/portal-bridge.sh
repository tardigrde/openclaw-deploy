#!/usr/bin/env bash
# =============================================================================
# Portal Bridge — expose an OpenClaw portal (container-internal listener) on
# the tailnet. Deployed/run via: make portal-bridge / portal-bridge-stop
#
# Usage: portal-bridge.sh [list|start|stop|status|fwd]   (default: status)
#
#   PORTAL=<portal-id>   OpenClaw portal id (from `portal.list`, e.g. p8765)
#                        Required for: start. (stop uses PORT instead.)
#   PORT=<stable-port>   Host loopback port + Tailscale Serve HTTPS port.
#                        Defaults to the portal's target port on start.
#                        Required for: stop.
#
# Why this exists: the gateway allocates each portal listener on an ephemeral
# port (port: 0) inside the gateway container's network namespace, and
# docker-compose.yml publishes only 18789 to the host. Tailscale Serve proxies
# host loopback ports only, so it can never reach the container-internal
# portal listener directly — Control UI → Portals shows "not reachable" with
# retry guidance. This script bridges the gap with a host-side TCP forwarder:
#
#   container dev server :TARGET
#     -> portal proxy (container 0.0.0.0:<listenPort>, token-authenticated)
#     -> python forwarder (host 127.0.0.1:<PORT>)
#     -> tailscale serve (https://<node>.<tailnet>.ts.net:<PORT>)
#
# The operator still opens the portal URL with the ?openclaw_portal=<token>
# query from the agent's `portal.open` result — auth is enforced by the
# gateway portal proxy, the forwarder just moves bytes.
#
# Requires on the host: docker, python3, screen, passwordless `sudo tailscale`
# (set once: sudo tailscale set --operator=$USER).
#
# Idempotent: start exits 0 if the bridge screen + serve proxy already exist.
# Portals die on gateway restart — re-run start afterwards (portal ids and
# listenPorts change, so always re-resolve via `list` first).
# =============================================================================
set -u

ACTION="${1:-status}"
PORTAL="${PORTAL:-}"
PORT="${PORT:-}"
LABEL="${GATEWAY_SERVICE_LABEL:-com.docker.compose.service=openclaw-gateway}"
SCREEN_PREFIX="${SCREEN_PREFIX:-portal-bridge}"

TS_FQDN="$(tailscale status --json 2>/dev/null | jq -r '.Self.DNSName' | sed 's/\.$//' || true)"
[ -z "$TS_FQDN" ] && TS_FQDN="<tailscale-fqdn>"

gateway_cid() {
  docker ps -q -f "label=${LABEL}" | head -n 1
}

gateway_bridge_ip() {
  local cid="$1"
  docker inspect "$cid" --format '{{range $k,$v := .NetworkSettings.Networks}}{{$v.IPAddress}}{{end}}'
}

# portal_field <portal-id> <jq-filter> — prints one field from portal.list
portal_field() {
  local cid="$1" id="$2" filter="$3"
  docker exec "$cid" openclaw gateway call portal.list 2>/dev/null \
    | tail -n +2 \
    | jq -r ".portals[] | select(.id==\"$id\") | $filter"
}

screen_name() {
  echo "${SCREEN_PREFIX}-$1"
}

is_port_free() {
  ! ss -tln 2>/dev/null | grep -qE "[:.]$1( |$)"
}

is_screen() {
  screen -ls 2>/dev/null | grep -q "\.$(screen_name "$1")	"
}

list() {
  local cid
  cid="$(gateway_cid)"
  if [ -z "$cid" ]; then
    echo "[portal-bridge] ERROR: gateway container not found (label $LABEL)." >&2
    exit 1
  fi
  echo "Portals (gateway $cid):"
  docker exec "$cid" openclaw gateway call portal.list 2>/dev/null \
    | tail -n +2 \
    | jq -r '.portals[] | "  \(.id)  target=\(.port)  listen=\(.listenPort)  title=\(.title)"' \
    || echo "  (none)"
  echo ""
  echo "Bridges (screen ${SCREEN_PREFIX}-<port> + tailscale serve):"
  screen -ls 2>/dev/null | grep -o "${SCREEN_PREFIX}-[0-9]*" | sort -u | sed 's/^/  screen: /' || echo "  (none)"
  tailscale serve status 2>/dev/null | grep -E "^https://" | sed 's/^/  serve: /' || true
}

# Internal action run inside screen: forward loopback TCP, no deps but python3.
fwd() {
  # args: <listen-port> <target-host> <target-port>
  python3 - "$1" "$2" "$3" <<'EOF'
import socket, threading, sys
listen_port, target_host, target_port = int(sys.argv[1]), sys.argv[2], int(sys.argv[3])
def pipe(a, b):
    try:
        while True:
            chunk = a.recv(65536)
            if not chunk:
                break
            b.sendall(chunk)
    except OSError:
        pass
    finally:
        for s in (a, b):
            try:
                s.shutdown(socket.SHUT_RDWR)
            except OSError:
                pass
def handle(client):
    try:
        upstream = socket.create_connection((target_host, target_port), timeout=8)
    except OSError:
        client.close()
        return
    workers = [threading.Thread(target=pipe, args=(client, upstream), daemon=True),
               threading.Thread(target=pipe, args=(upstream, client), daemon=True)]
    for w in workers:
        w.start()
    for w in workers:
        w.join()
srv = socket.socket(socket.AF_INET, socket.SOCK_STREAM)
srv.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
srv.bind(("127.0.0.1", listen_port))
srv.listen(50)
print(f"portal-bridge fwd ready: 127.0.0.1:{listen_port} -> {target_host}:{target_port}", flush=True)
while True:
    conn, _ = srv.accept()
    threading.Thread(target=handle, args=(conn,), daemon=True).start()
EOF
}

start() {
  if [ -z "$PORTAL" ]; then
    echo "[portal-bridge] ERROR: PORTAL=<portal-id> required (see: $0 list)." >&2
    exit 1
  fi
  for cmd in docker screen python3 jq tailscale ss; do
    command -v "$cmd" >/dev/null 2>&1 || { echo "[portal-bridge] ERROR: $cmd not installed on the host." >&2; exit 1; }
  done
  local cid listen target
  cid="$(gateway_cid)"
  [ -n "$cid" ] || { echo "[portal-bridge] ERROR: gateway container not found." >&2; exit 1; }
  listen="$(portal_field "$cid" "$PORTAL" '.listenPort')"
  target="$(portal_field "$cid" "$PORTAL" '.port')"
  if [ -z "$listen" ] || [ "$listen" = "null" ]; then
    echo "[portal-bridge] ERROR: portal '$PORTAL' not found. Available:" >&2
    list >&2
    exit 1
  fi
  [ -n "$PORT" ] || PORT="$target"
  if ! is_port_free "$PORT"; then
    if is_screen "$PORT"; then
      echo "  Bridge for :$PORT already running - nothing to do."
      echo "  https://${TS_FQDN}:${PORT}/?openclaw_portal=<token-from-portal.open>"
      exit 0
    fi
    echo "[portal-bridge] ERROR: host port $PORT already in use by something else." >&2
    exit 1
  fi
  local bridge
  bridge="$(gateway_bridge_ip "$cid")"
  [ -n "$bridge" ] || { echo "[portal-bridge] ERROR: no bridge IP for container $cid." >&2; exit 1; }
  # Quick reachability probe: 502 = portal proxy reachable, app not listening
  # yet (normal); connection failure = wrong network path, abort early.
  if ! curl -s --max-time 8 -o /dev/null "http://${bridge}:${listen}/" 2>/dev/null; then
    echo "[portal-bridge] ERROR: cannot reach ${bridge}:${listen} from host." >&2
    exit 1
  fi
  echo "  Bridging portal $PORTAL (target :$target, listen :$listen)..."
  echo "  Starting forwarder 127.0.0.1:$PORT -> $bridge:$listen in screen '$(screen_name "$PORT")'..."
  screen -dmS "$(screen_name "$PORT")" bash -c "exec \"$0\" fwd \"$PORT\" \"$bridge\" \"$listen\""
  sleep 1
  is_screen "$PORT" || { echo "[portal-bridge] ERROR: forwarder screen failed to start." >&2; exit 1; }
  echo "  Registering Tailscale serve proxy (HTTPS on :$PORT)..."
  if [ -f /etc/tailscale/serve.json ]; then
    echo "  NOTE: /etc/tailscale/serve.json exists (declarative mode)." >&2
    echo "  Imperative 'tailscale serve --bg' entries are reset on next 'make deploy'." >&2
    echo "  For a persistent bridge, add :$PORT to ansible/templates/tailscale-serve.json.j2" >&2
    echo "  (\"\${TS_CERT_DOMAIN}:$PORT\" -> Proxy http://127.0.0.1:$PORT) and re-run deploy." >&2
  fi
  sudo -n tailscale serve --bg --https="$PORT" "127.0.0.1:$PORT" >/dev/null 2>&1 \
    || echo "  WARN: tailscale serve failed (is 'sudo tailscale set --operator=\$USER' done?). HTTPS may be unavailable." >&2
  echo "  OK - https://${TS_FQDN}:${PORT}/?openclaw_portal=<token-from-portal.open>"
  echo "  (append the token query from the agent's portal.open result)"
}

stop() {
  if [ -z "$PORT" ]; then
    echo "[portal-bridge] ERROR: PORT=<stable-port> required." >&2
    exit 1
  fi
  if is_screen "$PORT"; then
    echo "  Stopping screen '$(screen_name "$PORT")'..."
    screen -S "$(screen_name "$PORT")" -X quit
  else
    echo "  No bridge screen for :$PORT."
  fi
  echo "  Removing Tailscale serve proxy for :$PORT..."
  sudo -n tailscale serve --https="$PORT" off >/dev/null 2>&1 \
    || echo "  WARN: tailscale serve off failed (ignored)." >&2
  echo "  Stopped."
}

case "$ACTION" in
  list|status)
    list
    ;;
  start)
    start
    ;;
  stop)
    stop
    ;;
  fwd)
    fwd "$2" "$3" "$4"
    ;;
  *)
    echo "[portal-bridge] ERROR: unknown action '$ACTION' (list|start|stop|status)." >&2
    exit 1
    ;;
esac
