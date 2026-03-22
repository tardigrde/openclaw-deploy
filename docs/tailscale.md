---
title: "Tailscale"
weight: 85
---
# Tailscale

OpenClaw uses Tailscale for private networking: SSH access from tailnet devices only, and HTTPS access to the gateway via Tailscale Serve.

## How it works

- **Terraform** manages the OAuth-generated pre-auth key, tailnet settings, and MagicDNS.
- **Ansible** installs Tailscale on the VPS, registers the node, and deploys the serve config.
- **`make bootstrap`** runs both automatically — no manual Tailscale console steps after initial setup.
- **`make deploy`** re-applies the serve config if it changed (idempotent, skipped before Tailscale is installed).

## Serve config

The gateway is exposed over Tailscale Serve via a JSON config file deployed by Ansible to `/etc/tailscale/serve.json`.

Template: `ansible/templates/tailscale-serve.json.j2`

Default (single service, port 18789 → HTTPS 443):

```json
{
  "TCP": {
    "443": { "HTTPS": true }
  },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": {
        "/": { "Proxy": "http://127.0.0.1:18789" }
      }
    }
  }
}
```

`${TS_CERT_DOMAIN}` is a Tailscale runtime placeholder — it is expanded by Tailscale to your device's FQDN (e.g. `openclaw-prod.tailnet-name.ts.net`). Do **not** replace it with a Jinja2 variable.

### Exposing additional services

To expose extra ports (e.g. Mission Control on 4000, a monitoring dashboard on 3001), add `TCPForward` entries:

```json
{
  "TCP": {
    "443": { "HTTPS": true },
    "4000": { "TCPForward": "127.0.0.1:4000" },
    "3001": { "TCPForward": "127.0.0.1:3001" }
  },
  "Web": {
    "${TS_CERT_DOMAIN}:443": {
      "Handlers": {
        "/": { "Proxy": "http://127.0.0.1:18789" }
      }
    }
  }
}
```

Then run `make deploy` — Ansible re-applies the config only if the file changed.

> **Private fork users:** If you maintain a private fork, override the template in your fork and protect it from upstream merges with `merge=ours` in `.gitattributes`. See your `docs/local/CLAUDE.md` for details.

## ACL management (optional)

Set `tailscale_enable_acl=true` in `terraform.tfvars` to manage your tailnet ACL via Terraform. **Warning:** this replaces the entire tailnet ACL on every `make apply`. Leave it `false` if you manage ACL rules in the Tailscale console.

## Rotating the auth key

The pre-auth key expires after 90 days. To rotate:

```bash
source secrets/inputs.sh && make apply
```

Terraform detects the expired key and creates a new one. Re-running `make tailscale-setup` or `make bootstrap` with the new key is only needed if the VPS node itself needs to re-register.

## Troubleshooting

**`make tailscale-enable` aborts** — Tailscale verification failed. SSH is still open. Check `make tailscale-status` and `make logs`.

**Can't reach VPS after locking SSH** — use the [Hetzner web console](https://console.hetzner.cloud/) → server → Console for emergency access.

**Serve not responding** — check config on VPS: `sudo tailscale serve status`. Re-apply with `make deploy`.
